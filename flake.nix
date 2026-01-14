{
  description = "Development environment for qluels-nvim (Zero-Build + Working Plugins)";

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

        # --- 1. Define Plugin Lists ---
        commonPlugins = with pkgs.vimPlugins; [
          plenary-nvim
          blink-cmp
          nvim-treesitter
        ];

        # Add telescope to the specific list
        telescopePlugins = commonPlugins ++ [ pkgs.vimPlugins.telescope-nvim ];

        # This takes a list of Nix packages and converts them into Lua code
        # that prepends their paths to the runtime path.
        # Result: "vim.opt.rtp:prepend('/nix/store/...-telescope')"
        mkPluginPath = plugins: 
          let
            toLua = p: "vim.opt.rtp:prepend('${p}')";
            lines = map toLua plugins;
          in
            builtins.concatStringsSep "\n" lines;

        # Generate the Lua blocks INSTANTLY during evaluation
        loadCommon = mkPluginPath commonPlugins;
        loadTelescope = mkPluginPath telescopePlugins;


        # --- 3. Lua Logic Strings (Same as before) ---
        initBlink = ''
          vim.opt.completeopt = { 'menuone', 'noselect', 'noinsert' }
          require('blink-cmp').setup({
            sources = {
              default = { "lsp", "path", "snippets", "buffer"},
              providers = {
                lsp = { name = 'LSP', module = 'blink.cmp.sources.lsp' }
              },
            },
            appearance = { use_nvim_cmp_as_default = true },
            keymap = { preset = 'enter' },
          })
        '';

        initQlueLS = ''
          require('qluels').setup({
            server = {
              capabilities = require('blink.cmp').get_lsp_capabilities(),
              on_attach = function(client, bufnr)
                  vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, { buffer = bufnr })
                  vim.keymap.set('n', '<leader>ex', ':QluelsExecute<cr>', { buffer = bufnr })
                  vim.keymap.set('n', '<leader>b', ':QluelsSetBackend<cr>', { buffer = bufnr })
              end,
            },
            auto_attach = true
          })
        '';

        qlue-ls-pkg = pkgs.rustPlatform.buildRustPackage rec {
          pname = "qlue-ls";
          version = "1.1.2-list";
          src = qlue-ls;
          cargoBuildFlags = [ "--bin" "qlue-ls" ];
          builtType = "debug";
          cargoLock.lockFile = "${qlue-ls}/Cargo.lock";
        };

        lua = pkgs.lua5_1.withPackages (ps: with ps; [ busted nlua plenary-nvim ]);

      in
      {
        devShells.default = pkgs.mkShell {
          # We still include them here so LSP/Lua can find them if needed,
          # but Neovim will rely on the hardcoded paths in init.lua.
          packages = [
            pkgs.neovim
            pkgs.luarocks
            lua
            qlue-ls-pkg
          ] ++ telescopePlugins;

          shellHook = ''
            # --- SETUP ENVIRONMENT ---
            export DEV_ENV="$PWD/.dev-env"
            export XDG_CONFIG_HOME="$DEV_ENV/config"
            export XDG_DATA_HOME="$DEV_ENV/data"
            export XDG_STATE_HOME="$DEV_ENV/state"
            
            export DEV_BIN="$DEV_ENV/bin"
            mkdir -p "$XDG_CONFIG_HOME" "$DEV_BIN"

            # --- GENERATE CONFIGS ---

            # 1. NVIM-TELESCOPE
            mkdir -p "$XDG_CONFIG_HOME/nvim-telescope"
            cat <<EOF > "$XDG_CONFIG_HOME/nvim-telescope/init.lua"
              vim.opt.termguicolors = true
              
              -- 1. Inject Nix Plugin Paths (Hardcoded)
              ${loadTelescope}

              -- 2. Inject Local Source (Priority)
              vim.opt.rtp:prepend(vim.fn.getcwd())

              -- 3. Configure
              require('telescope').setup({
                 defaults = { file_ignore_patterns = { "target/", ".git/" } }
              })
              ${initQlueLS}
              ${initBlink}
            EOF

            # 2. NVIM-MINIMAL
            mkdir -p "$XDG_CONFIG_HOME/nvim-minimal"
            cat <<EOF > "$XDG_CONFIG_HOME/nvim-minimal/init.lua"
              vim.opt.termguicolors = true
              
              -- 1. Inject Nix Plugin Paths (Hardcoded)
              ${loadCommon}

              -- 2. Inject Local Source
              vim.opt.rtp:prepend(vim.fn.getcwd())
              
              ${initQlueLS}
              ${initBlink}
            EOF

            # --- GENERATE WRAPPERS ---
            
            cat <<EOF > "$DEV_BIN/nvim-telescope"
            #!/bin/sh
            export NVIM_APPNAME="nvim-telescope"
            exec nvim "\$@"
            EOF
            chmod +x "$DEV_BIN/nvim-telescope"

            cat <<EOF > "$DEV_BIN/nvim-minimal"
            #!/bin/sh
            export NVIM_APPNAME="nvim-minimal"
            exec nvim "\$@"
            EOF
            chmod +x "$DEV_BIN/nvim-minimal"

            export PATH="$DEV_BIN:$PATH"

            echo "✅ Zero-Build Env Loaded"
          '';
        };
      }
    );
}
