local M = {}

-- Default options
M.config = {
  auto_import_on_completion = true,
  auto_import_on_save = false,
  auto_import_while_typing = false,
  organize_imports_on_save = true,
  max_unresolved_imports_on_save = 10,
  ui = {
    prefer_telescope = true,
  },
}

-- Diagnostic patterns that identify unresolved symbols
local unresolved_patterns = {
  "not defined",
  "undefined",
  "cannot find name",
  "undeclared name",
  "undeclared identifier",
  "cannot be resolved",
  "cannot find value",
  "cannot find type",
  "unresolved",
  "not found",
  "unknown symbol",
  "use of undeclared",
  "is not defined",
  "cannot find symbol",
  "must be imported",
}

-- LSP-specific regex patterns to identify import actions
local import_patterns = {
  ts_ls = {
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

-- Helper: Check if diagnostic indicates unresolved symbol
local function is_unresolved_diagnostic(diagnostic)
  local msg = diagnostic.message:lower()
  for _, pattern in ipairs(unresolved_patterns) do
    if msg:find(pattern, 1, true) then
      return true
    end
  end
  return false
end

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
    end
  elseif type(action.command) == "string" then
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

-- Caching Layer
local function get_cached_actions(bufnr, symbol)
  local ok, cache = pcall(vim.api.nvim_buf_get_var, bufnr, "autoimport_cache")
  if not ok or type(cache) ~= "table" then return nil end
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cache_entry = cache[symbol]
  if cache_entry and cache_entry.tick == tick then
    return cache_entry.actions
  end
  return nil
end

local function set_cached_actions(bufnr, symbol, actions)
  local ok, cache = pcall(vim.api.nvim_buf_get_var, bufnr, "autoimport_cache")
  if not ok or type(cache) ~= "table" then
    cache = {}
  end
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  cache[symbol] = {
    tick = tick,
    actions = actions,
  }
  vim.api.nvim_buf_set_var(bufnr, "autoimport_cache", cache)
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
        local display_text = string.format("[%s] %s", entry.client_name or "LSP", entry.action.title)
        return {
          value = entry,
          display = display_text,
          ordinal = display_text,
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
    table.insert(choices, string.format("[%s] %s", entry.client_name or "LSP", entry.action.title))
  end
  vim.ui.select(choices, {
    prompt = "Select Import:",
  }, function(choice, idx)
    if choice and idx then
      local selected = actions[idx]
      apply_action(selected.action, selected.client_id)
    end
  end)
end

-- Show Picker routing
local function show_import_picker(actions)
  if M.config.ui.prefer_telescope then
    local has_telescope, _ = pcall(require, "telescope")
    if has_telescope then
      local ok, err = pcall(select_action_telescope, actions)
      if ok then
        return
      else
        vim.notify("AutoImport: Telescope picker failed, falling back to vim.ui.select: " .. tostring(err), vim.log.levels.WARN)
      end
    end
  end
  select_action_ui(actions)
end

-- Trigger manual import
function M.trigger_auto_import()
  local bufnr = vim.api.nvim_get_current_buf()
  local symbol = vim.fn.expand("<cword>")
  if symbol == "" then
    vim.notify("AutoImport: No symbol under cursor.", vim.log.levels.WARN)
    return
  end

  local cached = get_cached_actions(bufnr, symbol)
  if cached then
    if #cached == 0 then
      vim.notify("AutoImport: No import candidates found for '" .. symbol .. "' (cached).", vim.log.levels.INFO)
    elseif #cached == 1 then
      apply_action(cached[1].action, cached[1].client_id)
    else
      show_import_picker(cached)
    end
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then
    vim.notify("AutoImport: No active LSP clients.", vim.log.levels.WARN)
    return
  end

  local params = vim.lsp.util.make_range_params()
  local line = params.range.start.line
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })
  local lsp_diagnostics = {}
  for _, d in ipairs(diagnostics) do
    if is_unresolved_diagnostic(d) then
      table.insert(lsp_diagnostics, {
        range = {
          start = { line = d.lnum, character = d.col },
          ["end"] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
        },
        severity = d.severity,
        code = d.code,
        source = d.source,
        message = d.message,
      })
    end
  end

  params.context = {
    diagnostics = lsp_diagnostics,
    triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
  }

  local completed = 0
  local all_actions = {}

  for _, client in ipairs(clients) do
    local c = client
    c:request("textDocument/codeAction", params, function(err, result)
      completed = completed + 1
      if not err and result then
        for _, action in ipairs(result) do
          if is_import_action(action, c.name) then
            table.insert(all_actions, {
              action = action,
              client_id = c.id,
              client_name = c.name,
            })
          end
        end
      end

      if completed == #clients then
        set_cached_actions(bufnr, symbol, all_actions)

        if #all_actions == 0 then
          vim.notify("AutoImport: No import candidates found for '" .. symbol .. "'.", vim.log.levels.INFO)
        elseif #all_actions == 1 then
          apply_action(all_actions[1].action, all_actions[1].client_id)
        else
          show_import_picker(all_actions)
        end
      end
    end, bufnr)
  end
end

-- Asynchronous/On-type single candidate automatic resolver
local function auto_import_on_cursor_line()
  local bufnr = vim.api.nvim_get_current_buf()
  if not vim.bo[bufnr].modifiable or vim.bo[bufnr].buftype ~= "" then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1

  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })
  if #diagnostics == 0 then return end

  local has_unresolved = false
  for _, d in ipairs(diagnostics) do
    if is_unresolved_diagnostic(d) then
      has_unresolved = true
      break
    end
  end

  if not has_unresolved then return end

  local symbol = vim.fn.expand("<cword>")
  if symbol == "" then return end

  local cached = get_cached_actions(bufnr, symbol)
  if cached then
    if #cached == 1 then
      apply_action(cached[1].action, cached[1].client_id)
    end
    return
  end

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then return end

  local params = vim.lsp.util.make_range_params()
  local lsp_diagnostics = {}
  for _, d in ipairs(diagnostics) do
    if is_unresolved_diagnostic(d) then
      table.insert(lsp_diagnostics, {
        range = {
          start = { line = d.lnum, character = d.col },
          ["end"] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
        },
        severity = d.severity,
        code = d.code,
        source = d.source,
        message = d.message,
      })
    end
  end

  params.context = {
    diagnostics = lsp_diagnostics,
    triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
  }

  local completed = 0
  local all_actions = {}

  for _, client in ipairs(clients) do
    local c = client
    c:request("textDocument/codeAction", params, function(err, result)
      completed = completed + 1
      if not err and result then
        for _, action in ipairs(result) do
          if is_import_action(action, c.name) then
            table.insert(all_actions, {
              action = action,
              client_id = c.id,
              client_name = c.name,
            })
          end
        end
      end

      if completed == #clients then
        set_cached_actions(bufnr, symbol, all_actions)
        if #all_actions == 1 then
          apply_action(all_actions[1].action, all_actions[1].client_id)
        end
      end
    end, bufnr)
  end
end

-- Debounced diagnostic event triggers
local timer = nil
local function debounce_auto_import(bufnr)
  if timer then
    pcall(function()
      timer:stop()
      timer:close()
    end)
    timer = nil
  end
  timer = vim.loop.new_timer()
  timer:start(1000, 0, function()
    vim.schedule(function()
      if timer and M.config.auto_import_while_typing and vim.api.nvim_buf_is_valid(bufnr) then
        M.auto_import_all_unresolved(bufnr)
      end
    end)
  end)
end

-- Organize imports: TypeScript/JavaScript specific
local function ts_organize_imports(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local client = nil
  for _, c in ipairs(clients) do
    if c.name == "ts_ls" or c.name == "tsserver" or c.name == "vtsls" then
      client = c
      break
    end
  end
  if not client then return false end

  local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" } }
  local response = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
  if response then
    for cid, res in pairs(response) do
      if res.result and res.result[1] then
        local action = res.result[1]
        local resp_client = vim.lsp.get_client_by_id(cid)
        if action.edit then
          local encoding = resp_client and resp_client.offset_encoding or client.offset_encoding
          vim.lsp.util.apply_workspace_edit(action.edit, encoding)
          return true
        elseif action.command then
          local target_client = resp_client or client
          target_client:request("workspace/executeCommand", action.command, function(err)
            if err then
              vim.notify("AutoImport: typescript organizeImports action failed: " .. tostring(err.message), vim.log.levels.ERROR)
            end
          end)
          return true
        end
      end
    end
  end

  -- Fallback command
  client:request("workspace/executeCommand", {
    command = "_typescript.organizeImports",
    arguments = { vim.api.nvim_buf_get_name(bufnr) },
  }, function(err)
    if err then
      vim.notify("AutoImport: typescript fallback organizeImports failed: " .. tostring(err.message), vim.log.levels.ERROR)
    end
  end)
  return false
end

-- Organize imports: Go specific
local function go_organize_imports(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })[1]
  if not client then return false end

  local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" } }
  local response, err = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
  if err then
    vim.notify("AutoImport: go organizeImports request failed: " .. tostring(err), vim.log.levels.ERROR)
  end
  if response then
    for cid, res in pairs(response) do
      if res.result then
        local resp_client = vim.lsp.get_client_by_id(cid)
        for _, action in ipairs(res.result) do
          if action.edit then
            local encoding = resp_client and resp_client.offset_encoding or client.offset_encoding
            vim.lsp.util.apply_workspace_edit(action.edit, encoding)
            return true
          elseif action.command then
            local target_client = resp_client or client
            target_client:request("workspace/executeCommand", action.command, function(err)
              if err then
                vim.notify("AutoImport: go organizeImports action failed: " .. tostring(err.message), vim.log.levels.ERROR)
              end
            end)
            return true
          end
        end
      end
    end
  end
  return false
end

-- Organize imports: Java specific
local function java_organize_imports(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1]
  if not client then return false end

  local done = false
  local success = false
  client:request("workspace/executeCommand", {
    command = "java.edit.organizeImports",
    arguments = { vim.uri_from_bufnr(bufnr) }
  }, function(err, result)
    if err then
      vim.notify("AutoImport: java organizeImports failed: " .. tostring(err.message), vim.log.levels.ERROR)
    elseif result then
      vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
      success = true
    end
    done = true
  end)

  -- Wait for up to 1000ms synchronously
  vim.wait(1000, function() return done end, 20)
  return success
end

-- Public: Organize imports in current buffer
function M.run_organize_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype

  if ft == "typescript" or ft == "javascript" or ft == "typescriptreact" or ft == "javascriptreact" then
    if ts_organize_imports(bufnr) then return end
  elseif ft == "go" then
    if go_organize_imports(bufnr) then return end
  elseif ft == "java" then
    if java_organize_imports(bufnr) then return end
  end

  local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" } }
  local response = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 1000)
  if response then
    for cid, res in pairs(response) do
      if res.result then
        local client = vim.lsp.get_client_by_id(cid)
        if client then
          for _, action in ipairs(res.result) do
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
            elseif action.command then
              client:request("workspace/executeCommand", action.command, function(err)
                if err then
                  vim.notify("AutoImport: general organizeImports action failed: " .. tostring(err.message), vim.log.levels.ERROR)
                end
              end)
            end
          end
        end
      end
    end
  end
end

-- Resolve all unique unresolved diagnostics in a buffer
function M.auto_import_all_unresolved(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.bo[bufnr].modifiable or vim.bo[bufnr].buftype ~= "" then
    return
  end
  local diagnostics = vim.diagnostic.get(bufnr)
  local unresolved = {}
  for _, d in ipairs(diagnostics) do
    if is_unresolved_diagnostic(d) then
      table.insert(unresolved, d)
    end
  end

  if #unresolved == 0 then return end

  -- Limit to a sane maximum to prevent LSP congestion
  local limit = math.min(#unresolved, M.config.max_unresolved_imports_on_save)

  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  if #clients == 0 then return end

  local completed_count = 0
  local total_requests = 0
  local pending_edits = {}

  for i = 1, limit do
    local d = unresolved[i]
    local params = vim.lsp.util.make_range_params()
    params.range = {
      start = { line = d.lnum, character = d.col },
      ["end"] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
    }
    params.context = {
      diagnostics = {
        {
          range = params.range,
          severity = d.severity,
          code = d.code,
          source = d.source,
          message = d.message,
        }
      },
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
    }

    for _, client in ipairs(clients) do
      local c = client
      total_requests = total_requests + 1
      c:request("textDocument/codeAction", params, function(err, result)
        completed_count = completed_count + 1
        if not err and result then
          local import_actions = {}
          for _, action in ipairs(result) do
            if is_import_action(action, c.name) then
              table.insert(import_actions, action)
            end
          end
          if #import_actions == 1 then
            table.insert(pending_edits, { action = import_actions[1], client_id = c.id })
          end
        end
      end, bufnr)
    end
  end

  -- Wait for up to 400ms for parallel requests to complete
  vim.wait(400, function()
    return completed_count >= total_requests
  end, 20)

  -- Apply unique edits
  for _, edit in ipairs(pending_edits) do
    apply_action(edit.action, edit.client_id)
  end
end

-- Integrated format-and-organize routine
function M.format_and_organize()
  local bufnr = vim.api.nvim_get_current_buf()
  if M.config.organize_imports_on_save then
    M.run_organize_imports(bufnr)
  end
  M.auto_import_all_unresolved(bufnr)

  -- Trigger formatter
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({ bufnr = bufnr, async = false })
  else
    vim.lsp.buf.format({ bufnr = bufnr, async = false })
  end
end

-- Set up autocmds & user commands
local function setup_autocmds()
  local group = vim.api.nvim_create_augroup("AutoImportGroup", { clear = true })

  -- BufWritePre trigger
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
      if M.config.auto_import_on_save then
        M.auto_import_all_unresolved(args.buf)
      end
    end,
  })

  -- On-type and post-diagnostic trigger (via diagnostic updates)
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = group,
    callback = function(args)
      if not M.config.auto_import_while_typing then return end
      debounce_auto_import(args.buf)
    end,
  })

  -- Clean up cache on buffer delete
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(args)
      pcall(vim.api.nvim_buf_del_var, args.buf, "autoimport_cache")
    end,
  })
end

-- Setup API
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  setup_autocmds()

  -- User commands
  vim.api.nvim_create_user_command("AutoImport", M.trigger_auto_import, {})
  vim.api.nvim_create_user_command("OrganizeImports", function()
    M.run_organize_imports(0)
  end, {})
  vim.api.nvim_create_user_command("FormatAndOrganize", M.format_and_organize, {})
end

return M
