local M = {}

function M.organize_imports(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "gopls" })[1]
  if not client then return false end

  local params = vim.lsp.util.make_range_params()
  params.context = { only = { "source.organizeImports" } }
  local response = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 200)
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
                vim.notify("AutoImport (Go): executeCommand failed: " .. tostring(err.message), vim.log.levels.ERROR)
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

return M
