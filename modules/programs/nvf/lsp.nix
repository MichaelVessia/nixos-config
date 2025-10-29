{pkgs, ...}: {
  programs.nvf.settings.vim = {
    lsp = {
      enable = true;
      formatOnSave = true;
      lspkind.enable = true;
      lspconfig = {
        enable = true;
        sources.ts-effect-lsp = ''
          lspconfig.ts_ls.setup {
            capabilities = capabilities;
            on_attach = default_on_attach;
            root_dir = require('lspconfig.util').root_pattern('package.json', 'tsconfig.json');
            init_options = {
              preferences = {
                importModuleSpecifierPreference = 'relative'
              }
            };
            on_new_config = function(new_config, new_root_dir)
              -- Use workspace TypeScript for @effect/language-service plugin
              local workspace_ts = new_root_dir .. "/node_modules/typescript/lib"
              if vim.fn.isdirectory(workspace_ts) == 1 then
                new_config.cmd = { "typescript-language-server", "--stdio", "--tsserver-path=" .. workspace_ts }
              end
            end;
          }
        '';
      };
      trouble.enable = true;
    };

    keymaps = [
      {
        key = "<leader>xx";
        mode = "n";
        action = "<cmd>Trouble diagnostics toggle<CR>";
        desc = "Toggle Trouble diagnostics";
      }
      {
        key = "gd";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.definition";
        desc = "Goto Definition";
      }
      {
        key = "gr";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.references";
        desc = "References";
      }
      {
        key = "gI";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.implementation";
        desc = "Goto Implementation";
      }
      {
        key = "gy";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.type_definition";
        desc = "Goto T[y]pe Definition";
      }
      {
        key = "gD";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.declaration";
        desc = "Goto Declaration";
      }
      {
        key = "K";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.hover";
        desc = "Hover";
      }
      {
        key = "gK";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.signature_help";
        desc = "Signature Help";
      }
      {
        key = "<c-k>";
        mode = "i";
        lua = true;
        action = "vim.lsp.buf.signature_help";
        desc = "Signature Help";
      }
      {
        key = "<leader>ca";
        mode = ["n" "x"];
        lua = true;
        action = "vim.lsp.buf.code_action";
        desc = "Code Action";
      }
      {
        key = "<leader>cc";
        mode = ["n" "x"];
        lua = true;
        action = "vim.lsp.codelens.run";
        desc = "Run Codelens";
      }
      {
        key = "<leader>cC";
        mode = "n";
        lua = true;
        action = "vim.lsp.codelens.refresh";
        desc = "Refresh & Display Codelens";
      }
      {
        key = "<leader>cr";
        mode = "n";
        lua = true;
        action = "vim.lsp.buf.rename";
        desc = "Rename";
      }
    ];
  };
}
