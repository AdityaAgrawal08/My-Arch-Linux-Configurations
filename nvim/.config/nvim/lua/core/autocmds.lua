-- Highlight on yank
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank({ higroup = "Visual", timeout = 120 })
  end,
})

-- Diagnostics configuration: no virtual_text, floating with border
vim.diagnostic.config({
  virtual_text = false,
  float = {
    border = "rounded",
    source = "if_many",
  },
  update_in_insert = false,
  severity_sort = true,
})

-- Show diagnostics on hover (CursorHold)
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
  callback = function()
    vim.diagnostic.open_float(nil, { focus = false })
  end,
})

-- Auto-resize splits when terminal window is resized
vim.api.nvim_create_autocmd("VimResized", {
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})

-- Filetype-specific indentation (4 spaces for these languages)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "java", "kotlin", "go", "c", "cpp" },
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
  end,
})

-- Remove trailing whitespace on save (skip non-modifiable/special buffers)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function(args)
    if not vim.bo[args.buf].modifiable or vim.bo[args.buf].buftype ~= "" then
      return
    end
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})

-- Return to last edit position when opening files
vim.api.nvim_create_autocmd("BufReadPost", {
  callback = function(args)
    local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(args.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      local win = vim.fn.bufwinid(args.buf)
      if win ~= -1 then
        pcall(vim.api.nvim_win_set_cursor, win, mark)
      end
    end
  end,
})

-- Markdown and text document configuration
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text" },
  callback = function(event)
    require("core.document").setup(event.buf)
  end,
})

-- Automatically populate Java package and class template for new files
vim.api.nvim_create_autocmd("BufNewFile", {
  pattern = "*.java",
  callback = function(args)
    local filepath = vim.api.nvim_buf_get_name(args.buf)
    if filepath == "" then return end

    -- Normalize slashes
    filepath = filepath:gsub("\\", "/")

    -- 1. Find the project root
    local root_files = { ".git", "pom.xml", "build.gradle", "settings.gradle", ".project" }
    local root_match = vim.fs.find(root_files, { path = filepath, upward = true })[1]
    local project_root = root_match and vim.fs.dirname(root_match) or nil

    local package_path = ""

    if project_root then
      -- Normalize project root slashes
      project_root = project_root:gsub("\\", "/")
      local dirpath = vim.fn.fnamemodify(filepath, ":h")
      
      -- If the file is inside the project root, extract the relative path
      if dirpath:sub(1, #project_root) == project_root then
        local rel_dir = dirpath:sub(#project_root + 2) -- +2 to skip separator
        
        -- Strip standard Java source directory prefixes
        local prefixes = {
          "src/main/java/",
          "src/test/java/",
          "src/",
          "lib/",
        }
        package_path = rel_dir
        for _, prefix in ipairs(prefixes) do
          if rel_dir:sub(1, #prefix) == prefix then
            package_path = rel_dir:sub(#prefix + 1)
            break
          end
        end
      end
    else
      -- Fallback to standard segment match if no root marker is found
      local patterns = {
        "/src/main/java/",
        "/src/test/java/",
        "/src/",
      }
      for _, pattern in ipairs(patterns) do
        local start_idx, end_idx = filepath:find(pattern, 1, true)
        if start_idx then
          local remaining = filepath:sub(end_idx + 1)
          local last_slash = remaining:find("/[^/]*$")
          if last_slash then
            package_path = remaining:sub(1, last_slash - 1)
          end
          break
        end
      end
    end

    -- Extract class/filename
    local filename = vim.fn.fnamemodify(filepath, ":t:r")
    if filename == "" then return end

    local lines = {}
    if package_path and package_path ~= "" then
      local package_name = package_path:gsub("/", ".")
      table.insert(lines, "package " .. package_name .. ";")
      table.insert(lines, "")
    end

    table.insert(lines, "public class " .. filename .. " {")
    table.insert(lines, "    ")
    table.insert(lines, "}")

    vim.api.nvim_buf_set_lines(args.buf, 0, -1, false, lines)

    -- Move cursor inside class body
    local cursor_line = (package_path and package_path ~= "") and 4 or 2
    pcall(vim.api.nvim_win_set_cursor, 0, { cursor_line, 4 })
  end,
})
