return {
  -- Mason: package manager for LSP servers, formatters, linters
  {
    "williamboman/mason.nvim",
    lazy = false,
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

  -- Mason-lspconfig bridge (managed synchronously to ensure correct startup order)
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = { "williamboman/mason.nvim", "neovim/nvim-lspconfig" },
  },

  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "saghen/blink.cmp",
      "j-hui/fidget.nvim",
      "folke/trouble.nvim",
    },

    config = function()
      -- Force load lspconfig plugin definitions to populate vim.lsp.config template database early
      vim.cmd("runtime! plugin/lspconfig.lua")

      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local on_attach = require("core.lsp").on_attach

      -- Explicitly negotiate advanced workspace/symbol and editor capabilities
      capabilities.workspace = capabilities.workspace or {}
      capabilities.workspace.symbol = {
        dynamicRegistration = false,
        symbolKind = {
          valueSet = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26 }
        }
      }
      capabilities.textDocument = capabilities.textDocument or {}
      capabilities.textDocument.semanticTokens = {
        dynamicRegistration = false,
        tokenTypes = { "namespace", "type", "class", "enum", "interface", "struct", "typeParameter", "parameter", "variable", "property", "enumMember", "event", "function", "method", "macro", "keyword", "modifier", "comment", "string", "number", "regexp", "operator", "decorator" },
        tokenModifiers = { "declaration", "definition", "readonly", "static", "deprecated", "abstract", "async", "modification", "documentation", "defaultLibrary" },
        formats = { "relative" },
        requests = {
          range = true,
          full = { delta = true }
        },
        overlappingTokenSupport = true,
        multilineTokenSupport = true
      }
      capabilities.textDocument.inlayHint = {
        dynamicRegistration = true,
        resolveSupport = {
          properties = { "textEdits", "tooltip", "location", "command" }
        }
      }

      -- Progress indicator
      require("fidget").setup({})
      -- Diagnostics panel
      require("trouble").setup({})

      -- Register custom keymaps and settings on LspAttach
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("LspAttachGroup", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client then
            on_attach(client, args.buf)
          end
        end,
      })

      -- List of servers to configure and ensure installed
      local servers = {
        -- Lua
        "lua_ls",
        -- Web
        "html", "cssls", "jsonls",
        "vtsls",
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
        -- Rust
        "rust_analyzer",
        -- Zig
        "zls",
        -- PHP
        "intelephense",
        -- C#
        "omnisharp",
      }

      -- Initialize Mason-LSPConfig
      require("mason-lspconfig").setup({
        ensure_installed = servers,
        automatic_enable = false,
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
              completeUnimported = true,
              deepCompletion = true,
              usePlaceholders = true,
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
                autoImportCompletions = true,
                diagnosticMode = "workspace",
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                typeCheckingMode = "basic",
              },
            },
          },
        },
        clangd = {
          cmd = {
            vim.fn.exepath("clangd") ~= "" and vim.fn.exepath("clangd") or "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders=true",
          },
        },
        vtsls = {
          settings = {
            typescript = {
              preferences = {
                includePackageJsonAutoImports = "on",
                importModuleSpecifierPreference = "non-relative",
              },
              inlayHints = {
                includeInlayParameterNameHints = "all",
                includeInlayFunctionParameterTypeHints = true,
                includeInlayVariableTypeHints = true,
              },
            },
            javascript = {
              preferences = {
                includePackageJsonAutoImports = "on",
                importModuleSpecifierPreference = "non-relative",
              },
            },
          },
        },
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              completion = {
                autoimport = { enable = true },
              },
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
              },
              procMacro = {
                enable = true,
              },
            },
          },
        },
        zls = {
          settings = {
            zls = {
              enable_autobuild = true,
            },
          },
        },
        intelephense = {
          settings = {
            intelephense = {
              completion = {
                fullyQualifyGlobalConstantsAndFunctions = true,
              },
            },
          },
        },
        omnisharp = {},
        jsonls = {
          settings = {
            json = {
              validate = { enable = true },
            },
          },
        },
        jdtls = {
          cmd = { "jdtls" },
          settings = {
            java = {
              signatureHelp = { enabled = true },
              contentProvider = { preferred = "fernflower" },
              completion = {
                favoriteStaticMembers = {
                  "org.hamcrest.MatcherAssert.assertThat",
                  "org.hamcrest.Matchers.*",
                  "org.hamcrest.CoreMatchers.*",
                  "org.junit.jupiter.api.Assertions.*",
                  "java.util.Objects.requireNonNull",
                  "java.util.Objects.requireNonNullElse",
                  "org.mockito.Mockito.*"
                },
                importOrder = {
                  "java",
                  "javax",
                  "com",
                  "org"
                }
              },
              sources = {
                organizeImports = {
                  starThreshold = 9999,
                  staticStarThreshold = 9999,
                },
              },
              codeGeneration = {
                toString = {
                  template = "${object.className}[${member.name()}=${member.value()}, ${otherMembers}]"
                },
                useBlocks = true,
              },
            },
          },
          root_dir = function(bufnr)
            local fname = vim.api.nvim_buf_get_name(bufnr)
            if fname == "" then
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
            return root and vim.fs.dirname(root) or vim.fs.dirname(fname)
          end,
        },
      }

      -- Base config configuration template
      local default_config = {
        capabilities = capabilities,
      }

      -- Synchronously configure and enable all servers natively at startup
      for _, server_name in ipairs(servers) do
        local config = vim.tbl_deep_extend("force", {}, default_config, server_settings[server_name] or {})
        vim.lsp.config(server_name, config)
        local ok, err = pcall(vim.lsp.enable, server_name)
        if not ok then
          vim.notify("Failed to enable LSP server " .. server_name .. ": " .. tostring(err), vim.log.levels.WARN)
        end
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
      "saghen/blink.cmp",
    },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()
      local on_attach = require("core.lsp").on_attach

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
