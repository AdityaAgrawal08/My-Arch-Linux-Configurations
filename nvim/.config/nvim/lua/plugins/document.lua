return {
  -- Markdown Live Preview in Browser
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = "cd app && ./install.sh",
  },

  -- Distraction-Free Writing Mode
  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    opts = {
      window = {
        backdrop = 0.95,
        width = 120,
        options = {
          signcolumn = "no",
          number = false,
          relativenumber = false,
          cursorline = false,
          cursorcolumn = false,
          foldcolumn = "0",
        },
      },
    },
  },

  -- Paragraph Dimming
  {
    "folke/twilight.nvim",
    cmd = "Twilight",
    opts = {},
  },

  -- Smooth Physics-based Scrolling
  {
    "karb94/neoscroll.nvim",
    keys = { "<C-u>", "<C-d>", "<C-b>", "<C-f>", "<C-y>", "<C-e>", "zt", "zz", "zb" },
    config = function()
      require("neoscroll").setup()
    end,
  },

  -- Paste Clipboard Images
  {
    "HakonHarnes/img-clip.nvim",
    cmd = "PasteImage",
    ft = { "markdown" },
    opts = {
      default = {
        dir_path = "assets",
        file_name = "%Y%m%d_%H%M%S",
        use_absolute_path = false,
        insert_mode = false,
        prompt_for_file_name = false,
      },
    },
  },

  -- Inline Images Preview using Kitty protocol (Lazy loaded)
  {
    "3rd/image.nvim",
    ft = { "markdown" },
    opts = {
      backend = "kitty",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = true,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown" },
        },
      },
      max_width = 100,
      max_height = 12,
      max_width_window_percentage = math.huge,
      max_height_window_percentage = math.huge,
      window_overlap_clear_enabled = true,
    },
  }
}
