{
  programs.nvf.settings.vim = {
    luaConfigRC.customFunctions = ''
      function SendContextToClipboard()
          -- Get the current file path
          local file_path = vim.fn.expand('%:p') -- %:p gets the full path

          -- Get the selected lines
          local start_line = vim.fn.getpos("'<")[2]
          local end_line = vim.fn.getpos("'>")[2]
          local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

          local formatted_snippet = ""
          -- Start with file path and range
          formatted_snippet = formatted_snippet .. "-- File: " .. file_path .. "\n"
          formatted_snippet = formatted_snippet .. "-- Lines: " .. start_line .. "-" .. end_line .. "\n\n"

          -- Add the code snippet with line numbers
          for i, line in ipairs(lines) do
              formatted_snippet = formatted_snippet .. (start_line + i - 1) .. ": " .. line .. "\n"
          end

          -- Use Neovim's built-in clipboard integration
          vim.fn.setreg('+', formatted_snippet)

          Snacks.notify("Context (File, Lines, Snippet) copied to clipboard!")
      end
    '';

    keymaps = [
      {
        key = "<leader>ctx";
        mode = "v";
        lua = true;
        action = "SendContextToClipboard";
        desc = "Send code context (file, lines, snippet) to clipboard";
      }
    ];
  };
}
