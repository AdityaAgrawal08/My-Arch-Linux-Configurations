local M = {}

M.on_attach = function(client, bufnr)
  local map = vim.keymap.set
  local opts = { buffer = bufnr, silent = true }

  if client.name == "ts_ls" then
    client.server_capabilities.documentFormattingProvider = false
  end

  -- LSP keymaps
  map("n", "gd", vim.lsp.buf.definition, opts)
  map("n", "gr", vim.lsp.buf.references, opts)
  map("n", "K", vim.lsp.buf.hover, opts)
  map("n", "<C-.>", vim.lsp.buf.code_action, opts)
  map("n", "<leader>rn", vim.lsp.buf.rename, opts)

  map("n", "<leader>f", function()
    vim.lsp.buf.format({ async = false })
  end, opts)

  -- Example: disable formatting for some servers if needed
  if client.name == "tsserver" then
    client.server_capabilities.documentFormattingProvider = false
  end
end

return M
