-- Core settings
require("core.options")
require("core.keymaps")
require("core.autoimport").setup({
  auto_import_while_typing = true,
  auto_import_on_save = true,
  organize_imports_on_save = true,
})
require("core.autocmds")

-- Plugins (lazy.nvim + specs)
require("plugins.init")
