local M = {}

function M.organize_imports(bufnr)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = "jdtls" })[1]
  if not client then return false end

  local done = false
  local success = false
  client:request("workspace/executeCommand", {
    command = "java.edit.organizeImports",
    arguments = { vim.uri_from_bufnr(bufnr) }
  }, function(err, result)
    if err then
      vim.notify("AutoImport (Java): organizeImports failed: " .. tostring(err.message), vim.log.levels.ERROR)
    elseif result then
      vim.lsp.util.apply_workspace_edit(result, client.offset_encoding)
      success = true
    end
    done = true
  end)

  -- Wait for up to 200ms synchronously
  vim.wait(200, function() return done end, 10)
  return success
end

return M
