local M = {}

-- Default options
M.config = {
  organize_imports_on_save = true,
  ui = {
    prefer_telescope = true,
  },
}

-- LSP-specific regex patterns to identify import actions
local import_patterns = {
  ts_ls = {
    "Import '.-' from",
    "Add import from",
    "Update import from",
    "Import {?.-}? from",
  },
  vtsls = {
    "Import '.-' from",
    "Add import from",
    "Update import from",
    "Import {?.-}? from",
  },
  pyright = {
    "Import %s*['\"].-['\"]%s*from",
    "From %s*.-%s*import",
    "Import %s*.-",
  },
  gopls = {
    "Import %s*['\"].-['\"]",
  },
  rust_analyzer = {
    "Import `.-`",
    "Use .-",
    "Add use .-",
  },
  clangd = {
    "Add #include",
    "Include ",
  },
  jdtls = {
    "Import '.-'",
    "Import ",
    "Correct package declaration",
    "Correct package",
  },
  kotlin_language_server = {
    "Import ",
  },
  default = {
    "import ",
    "Import ",
    "include",
    "using ",
    "use ",
    "require",
    "Require",
  }
}

-- Helper: Check if code action is an import
local function is_import_action(action, client_name)
  local title = type(action) == "table" and action.title or tostring(action)
  local kind = type(action) == "table" and action.kind or ""

  if kind == "source.addMissingImports" then
    return true
  end

  local lower_title = title:lower()

  -- Check client specific patterns
  local patterns = import_patterns[client_name]
  if patterns then
    for _, pattern in ipairs(patterns) do
      if title:find(pattern) or lower_title:find(pattern:lower()) then
        return true
      end
    end
  end

  -- Fallback to default check
  for _, pattern in ipairs(import_patterns.default) do
    if lower_title:find(pattern:lower(), 1, true) then
      if not lower_title:find("ignore") and not lower_title:find("disable") and not lower_title:find("suppress") then
        return true
      end
    end
  end

  return false
end

-- Helper: Apply WorkspaceEdit or Command programmatically
local function apply_action(action, client_id)
  local client = vim.lsp.get_client_by_id(client_id)
  if not client then return end

  if action.edit or action.command then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    elseif action.command then
      local cmd = action.command
      if type(cmd) == "table" then
        client:request("workspace/executeCommand", cmd, function(err, result)
          if err then
            vim.notify("AutoImport: Error executing command: " .. tostring(err.message), vim.log.levels.ERROR)
          end
        end)
      elseif type(cmd) == "string" then
        local params = {
          command = action.command,
          arguments = action.arguments,
        }
        client:request("workspace/executeCommand", params, function(err, result)
          if err then
            vim.notify("AutoImport: Error executing command: " .. tostring(err.message), vim.log.levels.ERROR)
          end
        end)
      end
    end
  else
    -- Try to resolve the action if it's unresolved
    client:request("codeAction/resolve", action, function(err, resolved_action)
      if not err and resolved_action then
        apply_action(resolved_action, client_id)
      end
    end)
  end
end

-- Telescope visual picker
local function select_action_telescope(actions)
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions_ts = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Auto Import Candidates",
    finder = finders.new_table({
      results = actions,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.action.title,
          ordinal = entry.action.title,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions_ts.select_default:replace(function()
        actions_ts.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          apply_action(selection.value.action, selection.value.client_id)
        end
      end)
      return true
    end,
  }):find()
end

-- Standard UI selection fallback
local function select_action_ui(actions)
  local choices = {}
  for _, entry in ipairs(actions) do
    table.insert(choices, entry.action.title)
  end
  vim.ui.select(choices, {
    prompt = "Select Import:",
  }, function(choice, idx)
    if choice and idx then
      apply_action(actions[idx].action, actions[idx].client_id)
    end
  end)
end

-- Trigger manual import asynchronously via native codeActions
function M.trigger_auto_import()
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  if filename == "" then
    vim.notify("AutoImport: Cannot run on unsaved buffers with no name.", vim.log.levels.WARN)
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    vim.notify("AutoImport: No active LSP clients.", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_range_params()
  params.context = {
    triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
  }

  local completed = 0
  local all_actions = {}

  for _, client in ipairs(clients) do
    local c = client
    c:request("textDocument/codeAction", params, function(err, result, ctx)
      completed = completed + 1
      if not err and result then
        for _, action in ipairs(result) do
          if is_import_action(action, c.name) then
            table.insert(all_actions, { action = action, client_id = c.id })
          end
        end
      end

      if completed == #clients then
        if #all_actions == 0 then
          vim.notify("AutoImport: No import candidates found.", vim.log.levels.INFO)
        elseif #all_actions == 1 then
          apply_action(all_actions[1].action, all_actions[1].client_id)
        else
          if M.config.ui.prefer_telescope then
            local has_telescope, _ = pcall(require, "telescope")
            if has_telescope then
              local ok, err_pick = pcall(select_action_telescope, all_actions)
              if ok then return end
              vim.notify("AutoImport: Telescope failed, falling back to UI select: " .. tostring(err_pick), vim.log.levels.WARN)
            end
          end
          select_action_ui(all_actions)
        end
      end
    end, bufnr)
  end
end

-- Organize imports: delegate to language-specific modules
function M.run_organize_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  local success = false
  if ft == "typescript" or ft == "javascript" or ft == "typescriptreact" or ft == "javascriptreact" then
    success = require("core.imports.ts").organize_imports(bufnr)
  elseif ft == "go" then
    success = require("core.imports.go").organize_imports(bufnr)
  elseif ft == "java" then
    success = require("core.imports.java").organize_imports(bufnr)
  else
    -- Fallback generic organize imports
    local params = vim.lsp.util.make_range_params()
    params.context = { only = { "source.organizeImports" } }
    local response = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 200)
    if response then
      for cid, res in pairs(response) do
        if res.result then
          local client = vim.lsp.get_client_by_id(cid)
          if client then
            for _, action in ipairs(res.result) do
              if action.edit then
                vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
                success = true
              elseif action.command then
                client:request("workspace/executeCommand", action.command, function(err)
                  if err then
                    vim.notify("AutoImport: organizeImports command failed: " .. tostring(err.message), vim.log.levels.ERROR)
                  end
                end)
                success = true
              end
            end
          end
        end
      end
    end
  end
  return success
end

-- Format and Organize Imports synchronously
function M.format_and_organize()
  local bufnr = vim.api.nvim_get_current_buf()
  if M.config.organize_imports_on_save then
    M.run_organize_imports(bufnr)
  end

  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({ bufnr = bufnr, async = false })
  else
    vim.lsp.buf.format({ bufnr = bufnr, async = false })
  end
end

-- Setup API & autocmds
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  local group = vim.api.nvim_create_augroup("AutoImportGroup", { clear = true })

  -- Organize imports asynchronously or with short timeout on BufWritePre
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = group,
    pattern = "*",
    callback = function(args)
      if not vim.bo[args.buf].modifiable or vim.bo[args.buf].buftype ~= "" then
        return
      end
      if M.config.organize_imports_on_save then
        M.run_organize_imports(args.buf)
      end
    end,
  })

  -- User commands
  vim.api.nvim_create_user_command("AutoImport", M.trigger_auto_import, {})
  vim.api.nvim_create_user_command("OrganizeImports", function()
    M.run_organize_imports(0)
  end, {})
  vim.api.nvim_create_user_command("FormatAndOrganize", M.format_and_organize, {})
end

return M
