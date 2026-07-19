return {
  -- Mason: package manager for LSP servers, formatters, linters
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = function()
      require("mason").setup({
        ui = {
          border = "rounded",
          icons = {
            package_installed = "✓",
            package_pending = "➜",
            package_uninstalled = "✗",
          },
        },
      })
    end,
  },

  -- Mason-lspconfig bridge (new API: automatic_enable via vim.lsp.enable)
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = {
          -- Lua
          "lua_ls",
          -- Web
          "html", "cssls", "jsonls",
          "ts_ls",
          -- C / C++
          "clangd",
          -- Python
          "pyright",
          -- Go
          "gopls",
          -- Java
          "jdtls",
          -- Kotlin
          "kotlin_language_server",
          -- LaTeX
          "texlab",
        },
        -- Disable automatic enable to avoid conflicts with setup_handlers
        automatic_enable = false,
      })
    end,
  },

  -- LSP configuration (via Neovim 0.11 native vim.lsp.config API)
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "j-hui/fidget.nvim",
      "folke/trouble.nvim",
    },

    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local on_attach = require("core.lsp").on_attach

      -- Enable folding capabilities for nvim-ufo
      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      -- Progress indicator
      require("fidget").setup({})
      -- Diagnostics panel
      require("trouble").setup({})

      -- Register custom keymaps and settings on LspAttach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            on_attach(client, args.buf)
          end
        end,
      })

      -- Server-specific settings overrides
      local server_settings = {
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = { globals = { "vim" } },
              workspace = {
                checkThirdParty = false,
                library = vim.api.nvim_get_runtime_file("", true),
              },
              telemetry = { enable = false },
            },
          },
        },
        gopls = {
          settings = {
            gopls = {
              analyses = {
                unusedparams = true,
                shadow = true,
              },
              staticcheck = true,
              gofumpt = true,
            },
          },
        },
        pyright = {
          settings = {
            python = {
              analysis = {
                typeCheckingMode = "basic",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
              },
            },
          },
        },
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders=true",
          },
        },
        ts_ls = {
          settings = {
            typescript = {
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
              },
            },
          },
        },
        jsonls = {
          settings = {
            json = {
              validate = { enable = true },
            },
          },
        },
        jdtls = {
          cmd = { "jdtls" },
          root_dir = function(bufnr, callback)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            if fname == "" then
              if callback then callback(nil) end
              return nil
            end
            local root_files = {
              "pom.xml",
              "build.gradle",
              "settings.gradle",
              "mvnw",
              "gradlew",
              ".git",
            }
            local root = vim.fs.find(root_files, { path = fname, upward = true })[1]
            local resolved = root and vim.fs.dirname(root) or vim.fs.dirname(fname)
            if callback then
              callback(resolved)
            end
            return resolved
          end,
        },
      }

      -- Set default capabilities globally for all servers
      vim.lsp.config("*", {
        capabilities = capabilities,
      })

      -- Apply overrides and enable all installed servers natively
      local mason_lspconfig = require("mason-lspconfig")
      for _, server_name in ipairs(mason_lspconfig.get_installed_servers()) do
        if server_settings[server_name] then
          vim.lsp.config(server_name, server_settings[server_name])
        end
        vim.lsp.enable(server_name)
      end
    end,
  },

  -- Flutter-tools (Dart/Flutter LSP — managed outside Mason)
  {
    "akinsho/flutter-tools.nvim",
    ft = { "dart" },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "neovim/nvim-lspconfig",
      "hrsh7th/cmp-nvim-lsp",
    },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()
      local on_attach = require("core.lsp").on_attach

      capabilities.textDocument.foldingRange = {
        dynamicRegistration = false,
        lineFoldingOnly = true,
      }

      require("flutter-tools").setup({
        lsp = {
          on_attach = on_attach,
          capabilities = capabilities,
          flags = { debounce_text_changes = 150 },
        },
        decorations = {
          statusline = {
            app_version = true,
            device = true,
          },
        },
        widget_guides = { enabled = true },
        closing_tags = { enabled = true },
      })
    end,
  },
}
