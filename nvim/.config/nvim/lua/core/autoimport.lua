local M = {}

M.config = {
  organize_imports_on_save = false,
  auto_import_on_save = false,
  auto_import_on_diagnostics = false,
  auto_import_while_typing = false,
  max_diagnostics = 8,
  ui = {
    prefer_telescope = true,
  },
}

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
  },
}

local function is_import_action(action, client_name)
  local title = type(action) == "table" and action.title or tostring(action)
  local kind = type(action) == "table" and action.kind or ""

  if kind == "source.addMissingImports" then
    return true
  end

  local lower_title = title:lower()
  local patterns = import_patterns[client_name]

  if patterns then
    for _, pattern in ipairs(patterns) do
      if title:find(pattern) or lower_title:find(pattern:lower(), 1, true) then
        return true
      end
    end
  end

  for _, pattern in ipairs(import_patterns.default) do
    if lower_title:find(pattern:lower(), 1, true)
        and not lower_title:find("ignore", 1, true)
        and not lower_title:find("disable", 1, true)
        and not lower_title:find("suppress", 1, true)
    then
      return true
    end
  end

  return false
end

local function apply_action(action, client_id)
  local client = vim.lsp.get_client_by_id(client_id)

  if not client then
    return
  end

  if action.edit then
    vim.lsp.util.apply_workspace_edit(action.edit, client.offset_encoding)
    return
  end

  if action.command then
    local command = action.command

    if type(command) == "table" then
      client:request("workspace/executeCommand", command, function(err)
        if err then
          vim.notify(
            "AutoImport: command failed: " .. tostring(err.message),
            vim.log.levels.ERROR
          )
        end
      end)
    elseif type(command) == "string" then
      client:request("workspace/executeCommand", {
        command = command,
        arguments = action.arguments,
      }, function(err)
        if err then
          vim.notify(
            "AutoImport: command failed: " .. tostring(err.message),
            vim.log.levels.ERROR
          )
        end
      end)
    end

    return
  end

  client:request("codeAction/resolve", action, function(err, resolved)
    if not err and resolved then
      apply_action(resolved, client_id)
    end
  end)
end

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
    attach_mappings = function(prompt_bufnr, _)
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

local function select_action_ui(actions)
  local choices = {}

  for _, entry in ipairs(actions) do
    choices[#choices + 1] = entry.action.title
  end

  vim.ui.select(choices, {
    prompt = "Select Import:",
  }, function(_, idx)
    if idx then
      apply_action(actions[idx].action, actions[idx].client_id)
    end
  end)
end

local function is_unresolved_diagnostic(diagnostic)
  if not diagnostic or not diagnostic.message then
    return false
  end

  local message = diagnostic.message:lower()

  return message:find("undeclared")
      or message:find("not found")
      or message:find("unresolved")
      or message:find("undefined")
      or message:find("cannot find")
      or message:find("could not find")
      or message:find("not declared")
      or message:find("unknown")
      or message:find("import")
      or message:find("include")
end

-- Convert a Neovim diagnostic range to an LSP range.
-- Diagnostic positions use zero-based lines/columns; make_given_range_params()
-- performs the required position-encoding conversion for the selected client.
local function diagnostic_range(diagnostic, bufnr, position_encoding)
  local start_pos = {
    (diagnostic.lnum or 0) + 1,
    diagnostic.col or 0,
  }

  local end_pos = {
    (diagnostic.end_lnum or diagnostic.lnum or 0) + 1,
    diagnostic.end_col or diagnostic.col or 0,
  }

  return vim.lsp.util.make_given_range_params(
    start_pos,
    end_pos,
    bufnr,
    position_encoding
  ).range
end

-- IMPORTANT:
-- Do not create code-action params with make_range_params() and then add
-- params.context. LuaLS correctly infers make_range_params() as returning
-- only { textDocument, range }, so mutating it with a new field produces
-- the "inject-field" diagnostic.
local function make_code_action_params(bufnr, range, context)
  ---@type lsp.CodeActionParams
  return {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
    range = range,
    context = context,
  }
end

local function request_code_actions(bufnr, params_builder, callback)
  vim.lsp.buf_request_all(
    bufnr,
    "textDocument/codeAction",
    params_builder,
    callback
  )
end

function M.auto_import_all_unresolved(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not vim.api.nvim_buf_is_valid(bufnr)
      or not vim.bo[bufnr].modifiable
      or vim.bo[bufnr].buftype ~= ""
  then
    return
  end

  local diagnostics = vim.diagnostic.get(bufnr)
  local unresolved = {}

  for _, diagnostic in ipairs(diagnostics) do
    if is_unresolved_diagnostic(diagnostic) then
      unresolved[#unresolved + 1] = diagnostic

      if #unresolved >= (M.config.max_diagnostics or 8) then
        break
      end
    end
  end

  if #unresolved == 0 then
    return
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = "textDocument/codeAction",
  })

  if #clients == 0 then
    return
  end

  local pending = {}
  local remaining = #unresolved

  for _, diagnostic in ipairs(unresolved) do
    request_code_actions(bufnr, function(client)
      local range = diagnostic_range(
        diagnostic,
        bufnr,
        client.offset_encoding
      )

      return make_code_action_params(bufnr, range, {
        diagnostics = {
          {
            range = range,
            severity = diagnostic.severity,
            code = diagnostic.code,
            source = diagnostic.source,
            message = diagnostic.message,
          },
        },
        triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
      })
    end, function(results)
      for client_id, response in pairs(results) do
        local client = vim.lsp.get_client_by_id(client_id)

        if client and response.result then
          local actions = response.result

          for _, action in ipairs(actions) do
            if is_import_action(action, client.name) then
              pending[#pending + 1] = {
                action = action,
                client_id = client_id,
              }
            end
          end
        end
      end

      remaining = remaining - 1

      if remaining ~= 0 then
        return
      end

      -- Avoid applying duplicate actions returned for the same diagnostic.
      local seen = {}

      for _, entry in ipairs(pending) do
        local title = entry.action.title or ""
        local key = tostring(entry.client_id) .. "\0" .. title

        if not seen[key] then
          seen[key] = true
          apply_action(entry.action, entry.client_id)
        end
      end
    end)
  end
end

function M.trigger_auto_import()
  local bufnr = vim.api.nvim_get_current_buf()

  if vim.api.nvim_buf_get_name(bufnr) == "" then
    vim.notify(
      "AutoImport: buffer has no filename.",
      vim.log.levels.WARN
    )
    return
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = "textDocument/codeAction",
  })

  if #clients == 0 then
    vim.notify(
      "AutoImport: no LSP code-action client is attached.",
      vim.log.levels.WARN
    )
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local line = cursor[1] - 1
  local col = cursor[2]
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })
  local lsp_diagnostics = {}

  for _, diagnostic in ipairs(diagnostics) do
    local start_col = diagnostic.col or 0
    local end_col = diagnostic.end_col or start_col

    if col >= start_col and col <= end_col then
      lsp_diagnostics[#lsp_diagnostics + 1] = {
        range = diagnostic_range(
          diagnostic,
          bufnr,
          clients[1].offset_encoding
        ),
        severity = diagnostic.severity,
        code = diagnostic.code,
        source = diagnostic.source,
        message = diagnostic.message,
      }
    end
  end

  if #lsp_diagnostics == 0 then
    for _, diagnostic in ipairs(diagnostics) do
      lsp_diagnostics[#lsp_diagnostics + 1] = {
        range = diagnostic_range(
          diagnostic,
          bufnr,
          clients[1].offset_encoding
        ),
        severity = diagnostic.severity,
        code = diagnostic.code,
        source = diagnostic.source,
        message = diagnostic.message,
      }
    end
  end

  if #lsp_diagnostics == 0 then
    M.auto_import_all_unresolved(bufnr)
    return
  end

  request_code_actions(bufnr, function(client)
    local cursor_range = vim.lsp.util.make_range_params(
      0,
      client.offset_encoding
    ).range

    local diagnostics_for_client = {}

    for _, diagnostic in ipairs(diagnostics) do
      diagnostics_for_client[#diagnostics_for_client + 1] = {
        range = diagnostic_range(
          diagnostic,
          bufnr,
          client.offset_encoding
        ),
        severity = diagnostic.severity,
        code = diagnostic.code,
        source = diagnostic.source,
        message = diagnostic.message,
      }
    end

    return make_code_action_params(bufnr, cursor_range, {
      diagnostics = diagnostics_for_client,
      triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
    })
  end, function(results)
    local all_actions = {}

    for client_id, response in pairs(results) do
      local client = vim.lsp.get_client_by_id(client_id)

      if client and response.result then
        for _, action in ipairs(response.result) do
          if is_import_action(action, client.name) then
            all_actions[#all_actions + 1] = {
              action = action,
              client_id = client_id,
            }
          end
        end
      end
    end

    if #all_actions == 0 then
      vim.notify(
        "AutoImport: no import candidates found.",
        vim.log.levels.INFO
      )
      return
    end

    if #all_actions == 1 then
      apply_action(all_actions[1].action, all_actions[1].client_id)
      return
    end

    if M.config.ui.prefer_telescope then
      local telescope_ok = pcall(require, "telescope")

      if telescope_ok then
        local picker_ok = pcall(
          select_action_telescope,
          all_actions
        )

        if picker_ok then
          return
        end
      end
    end

    select_action_ui(all_actions)
  end)
end

function M.run_organize_imports(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local ft = vim.bo[bufnr].filetype

  if ft == "typescript"
      or ft == "javascript"
      or ft == "typescriptreact"
      or ft == "javascriptreact"
  then
    local ok, imports = pcall(require, "core.imports.ts")

    if ok and imports.organize_imports then
      return imports.organize_imports(bufnr)
    end
  elseif ft == "go" then
    local ok, imports = pcall(require, "core.imports.go")

    if ok and imports.organize_imports then
      return imports.organize_imports(bufnr)
    end
  elseif ft == "java" then
    local ok, imports = pcall(require, "core.imports.java")

    if ok and imports.organize_imports then
      return imports.organize_imports(bufnr)
    end
  end

  local clients = vim.lsp.get_clients({
    bufnr = bufnr,
    method = "textDocument/codeAction",
  })

  if #clients == 0 then
    return false
  end

  local client = clients[1]

  local range = vim.lsp.util.make_range_params(
    0,
    client.offset_encoding
  ).range

  local params = make_code_action_params(bufnr, range, {
    only = { "source.organizeImports" },
    triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
  })

  local response = vim.lsp.buf_request_sync(
    bufnr,
    "textDocument/codeAction",
    params,
    500
  )

  if not response then
    return false
  end

  local success = false

  for client_id, result in pairs(response) do
    local result_data = result.result
    local active_client = vim.lsp.get_client_by_id(client_id)

    if active_client and result_data then
      for _, action in ipairs(result_data) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(
            action.edit,
            active_client.offset_encoding
          )
          success = true
        elseif action.command then
          active_client:request(
            "workspace/executeCommand",
            action.command,
            function(err)
              if err then
                vim.notify(
                  "AutoImport: organize imports command failed: "
                  .. tostring(err.message),
                  vim.log.levels.ERROR
                )
              end
            end
          )
          success = true
        end
      end
    end
  end

  return success
end

function M.format_and_organize()
  local bufnr = vim.api.nvim_get_current_buf()

  M.run_organize_imports(bufnr)
  M.auto_import_all_unresolved(bufnr)

  local ok, conform = pcall(require, "conform")

  if ok then
    conform.format({
      bufnr = bufnr,
      async = false,
      lsp_fallback = true,
    })
  else
    vim.lsp.buf.format({
      bufnr = bufnr,
      async = false,
    })
  end
end

local debounce_timers = {}

local function debounce_auto_import(bufnr)
  local old_timer = debounce_timers[bufnr]

  if old_timer then
    old_timer:stop()
    old_timer:close()
  end

  local timer = vim.uv.new_timer()

  if not timer then
    return
  end

  debounce_timers[bufnr] = timer

  timer:start(500, 0, vim.schedule_wrap(function()
    if debounce_timers[bufnr] ~= timer then
      return
    end

    debounce_timers[bufnr] = nil
    timer:close()

    M.auto_import_all_unresolved(bufnr)
  end))
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Deliberately no BufWritePre autocmd.
  -- This module must not rewrite buffers merely because they are saved.
  local group = vim.api.nvim_create_augroup("AutoImportGroup", {
    clear = true,
  })

  if M.config.auto_import_on_diagnostics
      or M.config.auto_import_while_typing
  then
    vim.api.nvim_create_autocmd("DiagnosticChanged", {
      group = group,
      callback = function(args)
        if vim.bo[args.buf].modifiable
            and vim.bo[args.buf].buftype == ""
        then
          debounce_auto_import(args.buf)
        end
      end,
      desc = "AutoImport: optionally react to diagnostic changes",
    })
  end

  vim.api.nvim_create_user_command(
    "AutoImport",
    M.trigger_auto_import,
    { desc = "Find and apply import code actions" }
  )

  vim.api.nvim_create_user_command(
    "OrganizeImports",
    function()
      M.run_organize_imports(0)
    end,
    { desc = "Organize imports using the configured LSP" }
  )

  vim.api.nvim_create_user_command(
    "FormatAndOrganize",
    M.format_and_organize,
    {
      desc = "Organize imports, auto-import unresolved symbols, and format",
    }
  )
end

return M
