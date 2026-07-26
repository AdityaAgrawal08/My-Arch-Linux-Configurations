local source = {}

function source.new(opts)
  return setmetatable({ opts = opts }, { __index = source })
end

local function get_file_extension(filename)
  return filename:match("^.+(%..+)$")
end

local function extract_symbols(content, filetype)
  local lang = vim.treesitter.language.get_lang(filetype) or filetype
  local ok, parser = pcall(vim.treesitter.get_string_parser, content, lang)
  if not ok or not parser then return {} end

  local ok_tree, tree = pcall(function() return parser:parse()[1] end)
  if not ok_tree or not tree then return {} end

  local root = tree:root()
  local symbols = {}
  local seen = {}

  local query = vim.treesitter.query.get(lang, "tags")
  if not query then
    query = vim.treesitter.query.get(lang, "locals")
  end

  if query then
    for id, node in query:iter_captures(root, content) do
      local name = query.captures[id]
      if name == "name" or name:match("^definition%.") or name:match("^local%.definition") then
        local text = vim.treesitter.get_node_text(node, content)
        if text and text ~= "" and not seen[text] then
          seen[text] = true
          table.insert(symbols, text)
        end
      end
    end
  else
    local fallback_query_str = "(identifier) @name"
    local ok_q, fallback_query = pcall(vim.treesitter.query.parse, lang, fallback_query_str)
    if ok_q and fallback_query then
      for _, node in fallback_query:iter_captures(root, content) do
        local text = vim.treesitter.get_node_text(node, content)
        if text and text ~= "" and not seen[text] then
          seen[text] = true
          table.insert(symbols, text)
        end
      end
    end
  end

  return symbols
end

local function read_file_async(path, callback)
  vim.uv.fs_open(path, "r", 438, function(err, fd)
    if err or not fd then return callback(nil) end
    vim.uv.fs_fstat(fd, function(stat_err, stat)
      if stat_err or not stat then
        vim.uv.fs_close(fd)
        return callback(nil)
      end
      vim.uv.fs_read(fd, stat.size, 0, function(read_err, data)
        vim.uv.fs_close(fd)
        callback(data)
      end)
    end)
  end)
end

function source:get_completions(context, callback)
  local bufnr = context.bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == "" then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local dir = vim.fn.fnamemodify(filepath, ":h")
  local current_ext = get_file_extension(filepath)
  if not current_ext then
    return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
  end

  local filetype = vim.bo[bufnr].filetype

  -- Asynchronously read files in the directory
  vim.uv.fs_scandir(dir, function(err, req)
    if err or not req then
      return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    end

    local files_to_read = {}
    while true do
      local name, type = vim.uv.fs_scandir_next(req)
      if not name then break end
      if type == "file" and get_file_extension(name) == current_ext and dir .. "/" .. name ~= filepath then
        table.insert(files_to_read, dir .. "/" .. name)
      end
    end

    if #files_to_read == 0 then
      return callback({ is_incomplete_forward = false, is_incomplete_backward = false, items = {} })
    end

    local all_items = {}
    local completed = 0

    for _, file in ipairs(files_to_read) do
      read_file_async(file, function(content)
        if content then
          -- Process treesitter on the main thread since it uses C API
          vim.schedule(function()
            local symbols = extract_symbols(content, filetype)
            for _, sym in ipairs(symbols) do
              table.insert(all_items, {
                label = sym,
                kind = require("blink.cmp.types").CompletionItemKind.Reference,
                detail = "Auto-import from " .. vim.fn.fnamemodify(file, ":t"),
                insertText = sym,
              })
            end
            
            completed = completed + 1
            if completed == #files_to_read then
              callback({
                is_incomplete_forward = false,
                is_incomplete_backward = false,
                items = all_items,
              })
            end
          end)
        else
          completed = completed + 1
          if completed == #files_to_read then
            callback({
              is_incomplete_forward = false,
              is_incomplete_backward = false,
              items = all_items,
            })
          end
        end
      end)
    end
  end)
end

function source:execute(context, item)
  -- Wait for the LSP to update diagnostics after the symbol is inserted
  vim.defer_fn(function()
    local clients = vim.lsp.get_clients({ bufnr = 0 })
    if #clients == 0 then return end
    
    local params = vim.lsp.util.make_range_params(0, clients[1].offset_encoding or "utf-16")
    params.context = { diagnostics = vim.diagnostic.get(0, { lnum = params.range.start.line }) }
    
    -- Request code actions
    vim.lsp.buf_request(0, "textDocument/codeAction", params, function(err, result, ctx)
      if err or not result then return end
      
      for _, action in pairs(result) do
        local title = action.title:lower()
        if title:match("import") or title:match("add include") or action.kind == "source.organizeImports" or (action.kind and action.kind:match("^quickfix")) then
          -- Resolve the code action if needed
          if action.edit or action.command then
            if action.edit then
              vim.lsp.util.apply_workspace_edit(action.edit, clients[1].offset_encoding or "utf-16")
            end
            if action.command then
              local client = vim.lsp.get_client_by_id(ctx.client_id)
              if client then
                client:request("workspace/executeCommand", action.command, function() end, ctx.bufnr)
              end
            end
            break
          else
            -- Needs resolution
            local client = vim.lsp.get_client_by_id(ctx.client_id)
            if client then
              client:request("codeAction/resolve", action, function(res_err, resolved_action)
                if not res_err and resolved_action and resolved_action.edit then
                  vim.lsp.util.apply_workspace_edit(resolved_action.edit, client.offset_encoding or "utf-16")
                end
              end)
            end
            break
          end
        end
      end
    end)
  end, 500)
end

return source
