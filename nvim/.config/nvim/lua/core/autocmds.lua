local augroup = vim.api.nvim_create_augroup("UserAutocmds", {
  clear = true,
})

-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  desc = "Highlight yanked text",
  callback = function()
    vim.hl.on_yank({
      higroup = "Visual",
      timeout = 120,
    })
  end,
})

-- Diagnostics configuration
vim.diagnostic.config({
  virtual_text = false,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "󰅚",
      [vim.diagnostic.severity.WARN] = "󰀦",
      [vim.diagnostic.severity.HINT] = "󰌵",
      [vim.diagnostic.severity.INFO] = "󰋼",
    },
  },
  float = {
    border = "rounded",
    source = "if_many",
  },
  update_in_insert = false,
  severity_sort = true,
})

-- Show diagnostics on hover
vim.api.nvim_create_autocmd("CursorHold", {
  group = augroup,
  desc = "Show diagnostics under cursor",
  callback = function()
    vim.diagnostic.open_float(nil, {
      focus = false,
    })
  end,
})

-- Auto-resize splits when terminal window is resized
vim.api.nvim_create_autocmd("VimResized", {
  group = augroup,
  desc = "Equalize windows after resize",
  callback = function()
    pcall(function()
      vim.cmd("tabdo wincmd =")
    end)
  end,
})

-- NOTE:
-- The old BufWritePre trailing-whitespace hook was intentionally removed.
--
-- It was:
--
-- vim.api.nvim_create_autocmd("BufWritePre", {
--   ...
--   vim.cmd([[%s/\s\+$//e]])
-- })
--
-- This prevents this file from modifying buffers during :write.

-- Return to last edit position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  desc = "Restore last cursor position",
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local line_count = vim.api.nvim_buf_line_count(args.buf)

    if mark[1] <= 0 or mark[1] > line_count then
      return
    end

    local win = vim.fn.bufwinid(args.buf)

    if win ~= -1 then
      pcall(vim.api.nvim_win_set_cursor, win, mark)
    end
  end,
})

-- Markdown and text document configuration
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = {
    "markdown",
    "text",
  },
  desc = "Configure text documents",
  callback = function(event)
    require("core.document").setup(event.buf)
  end,
})

-- Automatically populate Java package and class template
-- for new Java files
vim.api.nvim_create_autocmd("BufNewFile", {
  group = augroup,
  pattern = "*.java",
  desc = "Create Java class template",
  callback = function(args)
    local filepath = vim.api.nvim_buf_get_name(args.buf)

    if filepath == "" then
      return
    end

    -- Normalize path separators
    filepath = filepath:gsub("\\", "/")

    -- Find project root
    local root_files = {
      ".git",
      "pom.xml",
      "build.gradle",
      "settings.gradle",
      ".project",
    }

    local root_match = vim.fs.find(root_files, {
      path = filepath,
      upward = true,
    })[1]

    local project_root = root_match and vim.fs.dirname(root_match) or nil
    local package_path = ""

    if project_root then
      project_root = project_root:gsub("\\", "/")

      local dirpath = vim.fn.fnamemodify(filepath, ":h")

      -- Ensure the file is actually below the project root.
      if dirpath == project_root then
        package_path = ""
      elseif vim.startswith(dirpath, project_root .. "/") then
        local rel_dir = dirpath:sub(#project_root + 2)

        -- Strip standard Java source prefixes.
        local prefixes = {
          "src/main/java/",
          "src/test/java/",
          "src/",
          "lib/",
        }

        package_path = rel_dir

        for _, prefix in ipairs(prefixes) do
          if vim.startswith(rel_dir, prefix) then
            package_path = rel_dir:sub(#prefix + 1)
            break
          end
        end
      end
    else
      -- Fallback when no project root can be found.
      local patterns = {
        "/src/main/java/",
        "/src/test/java/",
        "/src/",
      }

      for _, pattern in ipairs(patterns) do
        local _, end_idx = filepath:find(pattern, 1, true)

        if end_idx then
          local remaining = filepath:sub(end_idx + 1)
          local last_slash = remaining:find("/[^/]*$")

          if last_slash then
            package_path = remaining:sub(1, last_slash - 1)
          end

          break
        end
      end
    end

    -- Extract class name from filename.
    local filename = vim.fn.fnamemodify(filepath, ":t:r")

    if filename == "" then
      return
    end

    local lines = {}

    if package_path ~= "" then
      local package_name = package_path:gsub("/", ".")

      table.insert(lines, "package " .. package_name .. ";")
      table.insert(lines, "")
    end

    table.insert(lines, "public class " .. filename .. " {")
    table.insert(lines, "    ")
    table.insert(lines, "}")

    vim.api.nvim_buf_set_lines(
      args.buf,
      0,
      -1,
      false,
      lines
    )

    -- Put cursor inside class body.
    local cursor_line = package_path ~= "" and 4 or 2

    pcall(
      vim.api.nvim_win_set_cursor,
      0,
      { cursor_line, 4 }
    )
  end,
})
