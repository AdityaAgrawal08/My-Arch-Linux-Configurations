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
  map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  map("n", "<leader>rn", function()
    local ok, _ = pcall(require, "inc_rename")
    if ok then
      return ":IncRename " .. vim.fn.expand("<cword>")
    else
      vim.schedule(function() vim.lsp.buf.rename() end)
      return "<Ignore>"
    end
  end, { expr = true, buffer = bufnr, silent = true })
  map("n", "gI", vim.lsp.buf.implementation, opts)
  map("n", "gy", vim.lsp.buf.type_definition, opts)
  map("n", "<leader>li", vim.lsp.buf.incoming_calls, opts)
  map("n", "<leader>lo", vim.lsp.buf.outgoing_calls, opts)
  map("n", "<leader>lh", vim.lsp.buf.typehierarchy, opts)
  map("n", "<leader>lf", vim.lsp.buf.format, opts)

  if client.server_capabilities.inlayHintProvider then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
  map("n", "<leader>th", function()
    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
  end, opts)

  -- Auto Import keymaps
  map("n", "<M-CR>", "<cmd>AutoImport<CR>", opts)
  map("n", "<leader>ai", "<cmd>AutoImport<CR>", opts)

  map("n", "<leader>f", function()
    require("core.autoimport").format_and_organize()
  end, opts)


end

return M
