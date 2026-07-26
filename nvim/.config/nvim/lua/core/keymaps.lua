local map = vim.keymap.set

-- Select all (preserves native <C-a> for number increment)
map("n", "<leader>a", "ggVG", { desc = "Select all" })

-- Save & quit shortcuts
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

-- Better window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Move to left window" })
map("n", "<C-j>", "<C-w>j", { desc = "Move to lower window" })
map("n", "<C-k>", "<C-w>k", { desc = "Move to upper window" })
map("n", "<C-l>", "<C-w>l", { desc = "Move to right window" })

-- Resize windows with arrows
map("n", "<C-Up>", "<cmd>resize +2<CR>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<CR>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", { desc = "Increase window width" })

-- Clear search highlight

-- Double Esc to clear search highlight
map("n", "<Esc><Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Buffer navigation
map("n", "]b", "<cmd>bnext<CR>", { desc = "Next buffer" })
map("n", "[b", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- Diagnostic navigation
map("n", "]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })

map("n", "[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })

map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic float" })

-- Better indenting (stay in visual mode)
map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })

-- Move lines up/down in visual mode (Note: Visual J overrides default line-join)
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down", silent = true })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up", silent = true })

-- Telescope (plugin will be lazy-loaded on use)
map("n", "<C-p>", "<cmd>Telescope find_files<CR>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>Telescope live_grep<CR>", { desc = "Grep" })
map("n", "<leader>fw", "<cmd>Telescope grep_string<CR>", { desc = "Grep string under cursor" })
map("n", "<leader>fb", "<cmd>Telescope buffers<CR>", { desc = "Buffers" })
map("n", "<leader>fh", "<cmd>Telescope help_tags<CR>", { desc = "Help tags" })
map("n", "<leader>fr", "<cmd>Telescope oldfiles<CR>", { desc = "Recent files" })

-- Telescope LSP / Search
map("n", "<leader>sw", "<cmd>Telescope lsp_dynamic_workspace_symbols<CR>", { desc = "Workspace symbols" })
map("n", "<leader>sd", "<cmd>Telescope lsp_document_symbols<CR>", { desc = "Document symbols" })
map("n", "<leader>sr", "<cmd>Telescope lsp_references<CR>", { desc = "References" })
map("n", "<leader>sD", "<cmd>Telescope diagnostics<CR>", { desc = "Workspace diagnostics" })
map("n", "<leader>sc", "<cmd>Telescope commands<CR>", { desc = "Commands" })
map("n", "<leader>sk", "<cmd>Telescope keymaps<CR>", { desc = "Keymaps" })

-- Git
map("n", "<leader>gs", "<cmd>Telescope git_status<CR>", { desc = "Git status" })
map("n", "<leader>gc", "<cmd>Telescope git_commits<CR>", { desc = "Git commits" })

-- Neo-tree toggle
map("n", "<C-n>", "<cmd>Neotree toggle<CR>", { desc = "Toggle Neo-tree" })

-- Trouble (diagnostics panel)
map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics (Trouble)" })
map("n", "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", { desc = "Buffer Diagnostics (Trouble)" })
map("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { desc = "Quickfix (Trouble)" })

-- Harpoon (Fast file switching)
map("n", "<leader>ha", function() require("harpoon"):list():add() end, { desc = "Harpoon Add File" })
map("n", "<leader>hm", function() local harpoon = require("harpoon") harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon Menu" })
map("n", "<C-1>", function() require("harpoon"):list():select(1) end, { desc = "Harpoon 1" })
map("n", "<C-2>", function() require("harpoon"):list():select(2) end, { desc = "Harpoon 2" })
map("n", "<C-3>", function() require("harpoon"):list():select(3) end, { desc = "Harpoon 3" })
map("n", "<C-4>", function() require("harpoon"):list():select(4) end, { desc = "Harpoon 4" })

-- Aerial (Outline / Structure)
map("n", "<leader>o", "<cmd>AerialToggle!<CR>", { desc = "Toggle Symbol Outline" })

-- Session Management
map("n", "<leader>qs", function() require("persistence").load() end, { desc = "Restore Session" })
map("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { desc = "Restore Last Session" })
