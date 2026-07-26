return {
  -- Treesitter (new API — highlight/indent are built into Neovim)
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      -- The new nvim-treesitter is a parser installer only.
      -- Highlight and indent are built into Neovim via vim.treesitter.
      require("nvim-treesitter").setup({
        ensure_installed = {
          -- Core
          "lua", "vim", "vimdoc", "query", "regex",
          -- Markup / Data
          "markdown", "markdown_inline", "html", "css", "json", "yaml", "toml", "latex",
          -- Your languages
          "c", "cpp", "java", "kotlin", "dart", "python", "go", "gomod", "gosum",
          "javascript", "typescript", "tsx",
          -- Shell / Config
          "bash", "dockerfile", "gitignore",
        },
      })
    end,
  },

  -- Treesitter Textobjects
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      local ok, ts_configs = pcall(require, "nvim-treesitter.configs")
      if ok then
        ts_configs.setup({
          textobjects = {
            select = {
              enable = true,
              lookahead = true,
              keymaps = {
                ["af"] = "@function.outer",
                ["if"] = "@function.inner",
                ["ac"] = "@class.outer",
                ["ic"] = "@class.inner",
                ["aP"] = "@parameter.outer",
                ["iP"] = "@parameter.inner",
              },
            },
            move = {
              enable = true,
              set_jumps = true,
              goto_next_start = {
                ["]]"] = "@function.outer",
                ["]m"] = "@class.outer",
              },
              goto_next_end = {
                ["]["] = "@function.outer",
                ["]M"] = "@class.outer",
              },
              goto_previous_start = {
                ["[["] = "@function.outer",
                ["[m"] = "@class.outer",
              },
              goto_previous_end = {
                ["[]"] = "@function.outer",
                ["[M"] = "@class.outer",
              },
            },
            swap = {
              enable = true,
              swap_next = {
                ["<leader>xn"] = "@parameter.inner",
              },
              swap_previous = {
                ["<leader>xp"] = "@parameter.inner",
              },
            },
          },
        })
      else
        local select = require("nvim-treesitter-textobjects.select")
        local move = require("nvim-treesitter-textobjects.move")
        local swap = require("nvim-treesitter-textobjects.swap")

        local maps = {
          af = "@function.outer",
          ["if"] = "@function.inner",
          ac = "@class.outer",
          ic = "@class.inner",
          aP = "@parameter.outer",
          iP = "@parameter.inner",
        }
        for k, v in pairs(maps) do
          vim.keymap.set({ "x", "o" }, k, function()
            select.select_textobject(v, "textobjects")
          end, { desc = "Select " .. v })
        end

        vim.keymap.set({ "n", "x", "o" }, "]]", function() move.goto_next_start("@function.outer", "textobjects") end, { desc = "Next function start" })
        vim.keymap.set({ "n", "x", "o" }, "]m", function() move.goto_next_start("@class.outer", "textobjects") end, { desc = "Next class start" })
        vim.keymap.set({ "n", "x", "o" }, "][", function() move.goto_next_end("@function.outer", "textobjects") end, { desc = "Next function end" })
        vim.keymap.set({ "n", "x", "o" }, "]M", function() move.goto_next_end("@class.outer", "textobjects") end, { desc = "Next class end" })
        vim.keymap.set({ "n", "x", "o" }, "[[", function() move.goto_previous_start("@function.outer", "textobjects") end, { desc = "Prev function start" })
        vim.keymap.set({ "n", "x", "o" }, "[m", function() move.goto_previous_start("@class.outer", "textobjects") end, { desc = "Prev class start" })
        vim.keymap.set({ "n", "x", "o" }, "[]", function() move.goto_previous_end("@function.outer", "textobjects") end, { desc = "Prev function end" })
        vim.keymap.set({ "n", "x", "o" }, "[M", function() move.goto_previous_end("@class.outer", "textobjects") end, { desc = "Prev class end" })

        vim.keymap.set("n", "<leader>xn", function() swap.swap_next("@parameter.inner", "textobjects") end, { desc = "Swap next parameter" })
        vim.keymap.set("n", "<leader>xp", function() swap.swap_previous("@parameter.inner", "textobjects") end, { desc = "Swap prev parameter" })
      end
    end,
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    event = "InsertEnter",
    dependencies = { "rafamadriz/friendly-snippets" },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },

  -- Completion
  {
    "saghen/blink.cmp",
    lazy = false, -- load early to provide capabilities to LSP
    version = "v0.*",
    dependencies = {
      "L3MON4D3/LuaSnip",
      "rafamadriz/friendly-snippets",
    },
    opts = {
      keymap = {
        preset = "default",
        ["<CR>"] = { "accept", "fallback" },
        ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
      },
      snippets = {
        preset = "luasnip",
      },
      sources = {
        default = { "lsp", "path", "snippets", "buffer", "neighbors" },
        providers = {
          neighbors = {
            name = "Neighbors",
            module = "core.completion.neighbors",
            score_offset = -1, -- Slightly lower priority than LSP
          },
        },
      },
      completion = {
        accept = {
          auto_brackets = {
            enabled = true,
          },
        },
        menu = {
          border = "rounded",
        },
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
          window = {
            border = "rounded",
          },
        },
      },
      signature = {
        enabled = true,
        window = {
          border = "rounded",
        },
      },
    },
  },

  -- Autopairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = function()
      require("nvim-autopairs").setup({})
    end,
  },

  -- Refactoring
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      { "<leader>re", ":Refactor extract_func<CR>", mode = "v", desc = "Extract Function" },
      { "<leader>rf", ":Refactor extract_func_to_file<CR>", mode = "v", desc = "Extract Function To File" },
      { "<leader>rv", ":Refactor extract_var<CR>", mode = "v", desc = "Extract Variable" },
      { "<leader>ri", ":Refactor inline_var<CR>", mode = { "n", "v" }, desc = "Inline Variable" },
      { "<leader>rI", ":Refactor inline_func<CR>", mode = "n", desc = "Inline Function" },
      { "<leader>rr", function() require("refactoring").select_refactor() end, mode = { "n", "v" }, desc = "Select Refactor" },
    },
    opts = {},
  },

  -- Formatter: conform.nvim
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = "ConformInfo",
    config = function()
      require("conform").setup({
        formatters_by_ft = {
          -- Markup / Data
          markdown = { "prettier" },
          html = { "prettier" },
          css = { "prettier" },
          json = { "prettier" },
          yaml = { "prettier" },
          -- Lua
          lua = { "stylua" },
          -- C / C++
          c = { "clang-format" },
          cpp = { "clang-format" },
          -- Python
          python = { "black" },
          -- Go
          go = { "gofumpt" },
          -- Java
          java = { "google-java-format" },
          -- Kotlin
          kotlin = { "ktlint" },
          -- Dart (handled by flutter-tools LSP, but as fallback)
          dart = { "dart_format" },
          -- JS / TS
          javascript = { "prettier" },
          typescript = { "prettier" },
          javascriptreact = { "prettier" },
          typescriptreact = { "prettier" },
          -- LaTeX
          tex = { "latexindent" },
          -- Rust & Zig
          rust = { "rustfmt" },
          zig = { "zigfmt" },
          -- Shell
          sh = { "shfmt" },
          bash = { "shfmt" },
        },
        format_on_save = {
          timeout_ms = 2000,
          lsp_fallback = true,
        },
      })
    end,
  },

  -- which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      require("which-key").setup()
    end,
  },

  -- Comment.nvim
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("Comment").setup()
    end,
  },

  -- nvim-surround
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },

  -- nvim-ufo (folding)
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      vim.o.foldcolumn = "1"
      vim.o.foldlevel = 99
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      require("ufo").setup({
        provider_selector = function(_, _, _)
          return { "treesitter", "indent" }
        end,
      })

      -- Keymaps for ufo
      vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
      vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
      vim.keymap.set("n", "zK", function()
        local winid = require("ufo").peekFoldedLinesUnderCursor()
        if not winid then
          vim.lsp.buf.hover()
        end
      end, { desc = "Peek fold" })
    end,
  },

  -- render-markdown
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    opts = {},
  },

  -- vimtex (LaTeX support)
  {
    "lervag/vimtex",
    ft = { "tex" },
    init = function()
      vim.g.vimtex_view_method = "zathura"
      vim.g.vimtex_compiler_method = "latexmk"
    end,
  },

  -- Session management
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = { options = vim.opt.sessionoptions:get() },
  },

  -- Highlight TODO, FIXME, HACK, etc.
  {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = { "BufReadPost", "BufNewFile" },
    opts = {},
  },
}
