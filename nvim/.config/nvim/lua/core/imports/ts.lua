local M = {}

function M.organize_imports(bufnr)
  local clients = vim.lsp.get_clients({ bufnr = bufnr })
  local client = nil
  for _, c in ipairs(clients) do
    if c.name == "vtsls" or c.name == "ts_ls" or c.name == "tsserver" then
      client = c
      break
    end
  end
  if not client then return false end

  local params = vim.lsp.util.make_range_params(0, client.offset_encoding or "utf-16")
  params.context = { only = { "source.organizeImports" } }
  local response = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 200)
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
              vim.notify("AutoImport (TS): executeCommand failed: " .. tostring(err.message), vim.log.levels.ERROR)
            end
          end)
          return true
        end
      end
    end
  end
  return false
end

return M
