return {
  -- Core DAP Engine
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "nvim-neotest/nvim-nio",
      "theHamsta/nvim-dap-virtual-text",
      "jay-babu/mason-nvim-dap.nvim",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      -- Setup DAP UI
      dapui.setup()

      -- Setup Virtual Text
      require("nvim-dap-virtual-text").setup()

      -- Automatically open/close DAP UI
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end

      -- Setup Mason integration
      require("mason-nvim-dap").setup({
        automatic_installation = true,
        ensure_installed = { "python", "delve" },
      })

      -- Set nice breakpoint icons
      vim.fn.sign_define('DapBreakpoint', { text='🔴', texthl='', linehl='', numhl='' })
      vim.fn.sign_define('DapStopped', { text='⭐️', texthl='', linehl='', numhl='' })

      -- Keymaps
      vim.keymap.set("n", "<F5>", dap.continue, { desc = "Debugger: Start/Continue" })
      vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debugger: Step Over" })
      vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debugger: Step Into" })
      vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debugger: Step Out" })
      vim.keymap.set("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debugger: Toggle Breakpoint" })
      vim.keymap.set("n", "<leader>du", dapui.toggle, { desc = "Debugger: Toggle UI" })
    end,
  },
}
