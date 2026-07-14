local M = {}

M.on_attach = function(client, bufnr)
  local map = vim.keymap.set
  local opts = { buffer = bufnr, silent = true }

  if client.name == "ts_ls" or client.name == "tsserver" then
    client.server_capabilities.documentFormattingProvider = false
  end

  -- LSP keymaps
  map("n", "gd", vim.lsp.buf.definition, opts)
  map("n", "gr", vim.lsp.buf.references, opts)
  map("n", "K", vim.lsp.buf.hover, opts)
  map("n", "<C-.>", vim.lsp.buf.code_action, opts)
  map("n", "<leader>rn", vim.lsp.buf.rename, opts)

  -- Auto Import keymaps
  map("n", "<M-CR>", "<cmd>AutoImport<CR>", opts)
  map("n", "<leader>ai", "<cmd>AutoImport<CR>", opts)

  map("n", "<leader>f", function()
    require("core.autoimport").format_and_organize()
  end, opts)


end

return M
