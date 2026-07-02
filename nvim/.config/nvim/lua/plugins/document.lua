-- Custom formatting helper functions
local function toggle_wrap(prefix, suffix)
  suffix = suffix or prefix
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Visual mode replacement
    vim.cmd("normal! \27") -- exit visual mode to set '< and '> marks
    local start_line = vim.fn.line("'<")
    local start_col = vim.fn.col("'<")
    local end_line = vim.fn.line("'>")
    local end_col = vim.fn.col("'>")
    
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    if #lines == 0 then return end
    
    if #lines == 1 then
      local line = lines[1]
      local before = string.sub(line, 1, start_col - 1)
      local selected = string.sub(line, start_col, end_col)
      local after = string.sub(line, end_col + 1)
      
      if string.sub(selected, 1, #prefix) == prefix and string.sub(selected, -#suffix) == suffix then
        selected = string.sub(selected, #prefix + 1, -#suffix - 1)
      else
        selected = prefix .. selected .. suffix
      end
      vim.api.nvim_buf_set_lines(0, start_line - 1, start_line, false, { before .. selected .. after })
    else
      lines[1] = string.sub(lines[1], 1, start_col - 1) .. prefix .. string.sub(lines[1], start_col)
      lines[#lines] = string.sub(lines[#lines], 1, end_col) .. suffix .. string.sub(lines[#lines], end_col + 1)
      vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
    end
  else
    -- Normal mode word wrap
    local word = vim.fn.expand("<cword>")
    if word == "" then return end
    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2] + 1
    
    local start_pos, end_pos = line:find(word, 1, true)
    if not start_pos then return end
    
    local before = string.sub(line, 1, start_pos - 1)
    local after = string.sub(line, end_pos + 1)
    
    local wrapped_before = string.sub(before, -#prefix) == prefix
    local wrapped_after = string.sub(after, 1, #suffix) == suffix
    if wrapped_before and wrapped_after then
      before = string.sub(before, 1, -#prefix - 1)
      after = string.sub(after, #suffix + 1)
    else
      word = prefix .. word .. suffix
    end
    vim.api.nvim_set_current_line(before .. word .. after)
  end
end

local function prepend_lines(prefix)
  local mode = vim.fn.mode()
  local start_line, end_line
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    start_line = vim.fn.line(".")
    end_line = start_line
  else
    vim.cmd("normal! \27")
    start_line = vim.fn.line("'<")
    end_line = vim.fn.line("'>")
  end
  
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  for i, line in ipairs(lines) do
    if string.sub(line, 1, #prefix) == prefix then
      lines[i] = string.sub(line, #prefix + 1)
    else
      lines[i] = prefix .. line
    end
  end
  vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end

local function insert_at_cursor(text)
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_get_current_line()
  local before = string.sub(line, 1, col)
  local after = string.sub(line, col + 1)
  vim.api.nvim_set_current_line(before .. text .. after)
end

local function insert_link()
  vim.ui.input({ prompt = "Link Text: " }, function(text)
    if not text then return end
    vim.ui.input({ prompt = "URL: ", default = "https://" }, function(url)
      if not url then return end
      insert_at_cursor(string.format("[%s](%s)", text, url))
    end)
  end)
end

local function insert_table()
  vim.ui.input({ prompt = "Columns: ", default = "3" }, function(cols_str)
    local cols = tonumber(cols_str) or 3
    vim.ui.input({ prompt = "Rows: ", default = "2" }, function(rows_str)
      local rows = tonumber(rows_str) or 2
      
      local header = "|"
      local separator = "|"
      for i = 1, cols do
        header = header .. " Header " .. i .. " |"
        separator = separator .. " -------- |"
      end
      
      local lines = { header, separator }
      for r = 1, rows do
        local row_str = "|"
        for c = 1, cols do
          row_str = row_str .. " Cell |"
        end
        table.insert(lines, row_str)
      end
      
      local row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_set_lines(0, row, row, false, lines)
    end)
  end)
end

local function toggle_checkbox()
  local line = vim.api.nvim_get_current_line()
  if line:match("^%s*[%-%*]%s+%[%s+%]") then
    line = line:gsub("^%s*([%-%*])%s+%[%s+%]", "%1 [x]", 1)
  elseif line:match("^%s*[%-%*]%s+%[x%]") then
    line = line:gsub("^%s*([%-%*])%s+%[x%]", "%1 [ ]", 1)
  else
    if line:match("^%s*[%-%*]%s+") then
      line = line:gsub("^%s*([%-%*])%s+", "%1 [ ] ", 1)
    else
      line = line:gsub("^(%s*)", "%1- [ ] ", 1)
    end
  end
  vim.api.nvim_set_current_line(line)
end

-- Custom Markdown Toolbar Picker
local function apply_format(choice)
  if choice == "Bold" then
    toggle_wrap("**")
  elseif choice == "Italic" then
    toggle_wrap("*")
  elseif choice == "Underline" then
    toggle_wrap("<u>", "</u>")
  elseif choice == "Strikethrough" then
    toggle_wrap("~~")
  elseif choice == "Bullet List" then
    prepend_lines("- ")
  elseif choice == "Numbered List" then
    prepend_lines("1. ")
  elseif choice == "Quote" then
    prepend_lines("> ")
  elseif choice == "Heading 1" then
    prepend_lines("# ")
  elseif choice == "Heading 2" then
    prepend_lines("## ")
  elseif choice == "Heading 3" then
    prepend_lines("### ")
  elseif choice == "Code Block" then
    toggle_wrap("```\n", "\n```")
  elseif choice == "Horizontal Rule" then
    insert_at_cursor("\n---\n")
  elseif choice == "Link" then
    insert_link()
  elseif choice == "Table" then
    insert_table()
  elseif choice == "Checkbox" then
    toggle_checkbox()
  end
end

local function show_toolbar()
  local items = {
    "Bold", "Italic", "Underline", "Strikethrough",
    "Bullet List", "Numbered List", "Quote",
    "Heading 1", "Heading 2", "Heading 3",
    "Code Block", "Horizontal Rule", "Link", "Table", "Checkbox"
  }
  vim.ui.select(items, {
    prompt = "Markdown Formatting Toolbar",
  }, function(choice)
    if not choice then return end
    apply_format(choice)
  end)
end

-- Focus / Zen Mode
local focus_active = false
local original_scrolloff = vim.wo.scrolloff

local function toggle_focus_mode()
  focus_active = not focus_active
  if focus_active then
    original_scrolloff = vim.wo.scrolloff
    vim.wo.scrolloff = 999
    vim.wo.wrap = true
    vim.wo.linebreak = true
    vim.wo.spell = true
    
    pcall(function()
      vim.cmd("ZenMode")
      vim.cmd("Twilight")
    end)
    vim.notify("Focus Mode Enabled (Typewriter scroll active)", vim.log.levels.INFO)
  else
    vim.wo.scrolloff = original_scrolloff
    vim.wo.spell = false
    
    pcall(function()
      vim.cmd("ZenMode")
      vim.cmd("Twilight")
    end)
    vim.notify("Focus Mode Disabled", vim.log.levels.INFO)
  end
end

-- Image resizing function
local function resize_image(args)
  local arg = args.args
  if not arg or arg == "" then
    vim.notify("Usage: :ImageResize 50 (or :ImageResize 300x200)", vim.log.levels.ERROR)
    return
  end
  
  local line = vim.api.nvim_get_current_line()
  local path = line:match("!%[.-%]%((.-)%)")
  if not path then
    vim.notify("No markdown image reference found on current line.", vim.log.levels.ERROR)
    return
  end
  
  local buf_dir = vim.fn.expand("%:p:h")
  local abs_path = vim.fn.simplify(buf_dir .. "/" .. path)
  
  if vim.fn.filereadable(abs_path) == 0 then
    vim.notify("Image file not found: " .. abs_path, vim.log.levels.ERROR)
    return
  end
  
  local resize_arg
  if arg:match("^%d+$") then
    resize_arg = arg .. "%"
  elseif arg:match("^%d+x%d+$") then
    resize_arg = arg .. "!"
  else
    resize_arg = arg
  end
  
  local cmd = string.format("mogrify -resize %s %q", resize_arg, abs_path)
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("Resized image to " .. arg, vim.log.levels.INFO)
        pcall(function()
          require("image").clear()
        end)
      else
        vim.notify("Failed to resize image using mogrify.", vim.log.levels.ERROR)
      end
    end
  })
end

-- Pandoc document export
local function export_document(format)
  local infile = vim.fn.expand("%:p")
  local outfile = vim.fn.expand("%:p:r") .. "." .. format
  
  if infile == "" then
    vim.notify("Buffer must be saved to a file first.", vim.log.levels.ERROR)
    return
  end
  
  vim.notify("Exporting to " .. format:upper() .. "...", vim.log.levels.INFO)
  local cmd = string.format("pandoc %q -o %q", infile, outfile)
  
  vim.fn.jobstart(cmd, {
    on_exit = function(_, exit_code)
      if exit_code == 0 then
        vim.notify("Successfully exported to " .. outfile, vim.log.levels.INFO)
      else
        vim.notify("Export failed. Make sure 'pandoc' is installed.", vim.log.levels.ERROR)
      end
    end
  })
end

local function show_export_menu()
  local items = { "PDF", "HTML", "DOCX" }
  vim.ui.select(items, {
    prompt = "Export Document Format",
  }, function(choice)
    if not choice then return end
    export_document(choice:lower())
  end)
end

-- Setup function for a specific buffer
local function apply_buffer_settings(bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set({ "n", "v" }, "<C-b>", function() toggle_wrap("**") end, opts)
  vim.keymap.set({ "n", "v" }, "<C-i>", function() toggle_wrap("*") end, opts)
  vim.keymap.set("n", "<C-Space>", toggle_checkbox, opts)
  
  vim.keymap.set("n", "<leader>mt", show_toolbar, opts)
  vim.keymap.set("n", "<leader>mi", ":PasteImage<CR>", opts)
  vim.keymap.set("n", "<leader>ml", insert_link, opts)
  vim.keymap.set("n", "<leader>mp", ":MarkdownPreviewToggle<CR>", opts)
  vim.keymap.set("n", "<leader>me", show_export_menu, opts)
  vim.keymap.set("n", "<leader>mf", toggle_focus_mode, opts)

  -- Document writing preferences
  vim.wo.wrap = true
  vim.wo.linebreak = true
  vim.wo.spell = true
end

-- Register keymaps and autocmds
local function setup_document_mode()
  -- User Commands
  vim.api.nvim_create_user_command("MarkdownToolbar", show_toolbar, {})
  vim.api.nvim_create_user_command("ImageResize", resize_image, { nargs = 1 })
  vim.api.nvim_create_user_command("ExportPDF", function() export_document("pdf") end, {})
  vim.api.nvim_create_user_command("ExportHTML", function() export_document("html") end, {})
  vim.api.nvim_create_user_command("ExportDOCX", function() export_document("docx") end, {})
  vim.api.nvim_create_user_command("ExportMenu", show_export_menu, {})
  vim.api.nvim_create_user_command("FocusModeToggle", toggle_focus_mode, {})

  -- FileType Autocommand for markdown and text
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text" },
    callback = function(event)
      apply_buffer_settings(event.buf)
    end
  })

  -- Fallback: If Neovim was launched directly with a markdown/text file,
  -- apply settings to the active buffer immediately.
  vim.schedule(function()
    local ft = vim.bo.filetype
    if ft == "markdown" or ft == "text" then
      apply_buffer_settings(0)
    end
  end)
end

setup_document_mode()

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
        prompt_for_file_name = false, -- Automatically save without prompting for name
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
