{
  description = "Development environment for qluels-nvim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    qlue-ls = {
      url = "git+file:///Users/mgthesecond/projects/foss/Qlue-ls/";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, qlue-ls }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        qlue-ls-pkg = pkgs.rustPlatform.buildRustPackage rec {
          pname = "qlue-ls";
          version = "1.1.2-list";

          src = qlue-ls;
          # Build only the binary, not the WASM library
          cargoBuildFlags = [ "--bin" "qlue-ls" ];
          builtType = "debug";
          cargoLock.lockFile = "${qlue-ls}/Cargo.lock";
        };

        devVimPlugins = with pkgs.vimPlugins; [
          plenary-nvim
          telescope-nvim
          blink-cmp
          nvim-treesitter
        ];

        testNeovim = pkgs.wrapNeovim pkgs.neovim-unwrapped {
          configure = {
            packages.devEnvironment = {
              # Plugins loaded on start
              start = devVimPlugins;
            };

            # 3. The "Rewire" Logic
            # We inject a Lua config that prepends the current directory (CWD)
            # to the Runtime Path. This makes Neovim load your local plugin source.
            customRC = ''
              set termguicolors
              lua << EOF
                local plugin_dir = vim.fn.getcwd()
                
                vim.opt.rtp:prepend(plugin_dir)



                require('telescope').setup({
                  defaults = {
                    file_ignore_patterns = {
                      "target/",
                      "project/target/",
                      ".git/",
                    }
                  }
                })


                require('qluels').setup({
                  server = {
                    capabilities = require('blink.cmp').get_lsp_capabilities(),
                    on_attach = function(client, bufnr)
                       vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, { buffer = bufnr, desc = 'LSP: ' .. '[F]ormat' })
                       vim.keymap.set('n', '<leader>ex', ':QluelsExecute<cr>', { buffer = bufnr, desc = 'Execute SPARQL buffer' })
                       vim.keymap.set('n', '<leader>b', ':QluelsSetBackend<cr>', { buffer = bufnr, desc = 'Execute SPARQL buffer' })
                    end,
                  },
                  auto_attach = true
                })
                
                print("🚧 Dev Environment Active: Loaded plugin from " .. plugin_dir)
              EOF
            '';
          };
        };

        # Create a Lua environment with test dependencies from nixpkgs
        lua = pkgs.lua5_1.withPackages (ps: with ps; [
          busted
          nlua
          plenary-nvim
        ]);
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [
            testNeovim
            lua
            pkgs.luarocks
            qlue-ls-pkg
          ];

          shellHook = ''
          '';
        };
      }
    );
}
