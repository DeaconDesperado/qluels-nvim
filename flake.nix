{
  description = "Development environment for qluels-nvim (Proper Nix)";

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

        # --- 1. PLUGINS ---
        commonPlugins = with pkgs.vimPlugins; [
          plenary-nvim
          blink-cmp
          nvim-treesitter
        ];

        telescopePlugins = commonPlugins ++ [ pkgs.vimPlugins.telescope-nvim ];
        fzfPlugins = commonPlugins ++ [
          pkgs.vimPlugins.nvim-web-devicons 
          pkgs.vimPlugins.fzf-lua
        ];

        # --- 2. HELPERS ---
        # Helper to inject plugin paths directly into RTP
        mkPluginPath = plugins: 
          let
            toLua = p: "vim.opt.rtp:prepend('${p}')";
            lines = map toLua plugins;
          in
            builtins.concatStringsSep "\n" lines;

        loadCommon = mkPluginPath commonPlugins;
        loadTelescope = mkPluginPath telescopePlugins;
        loadFzfLua = mkPluginPath fzfPlugins;

        # --- 3. LUA FRAGMENTS ---
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

        # --- 4. NIX FILE GENERATION (The Change) ---
        
        # A. Create the Config Files in the Nix Store
        # pkgs.writeText is incredibly fast (just copies string to store).
        
        telescopeLua = pkgs.writeText "init-telescope.lua" ''
          vim.opt.termguicolors = true
          ${loadTelescope}
          vim.opt.rtp:prepend(vim.fn.getcwd())
          require('telescope').setup({
             defaults = { file_ignore_patterns = { "target/", ".git/" } }
          })
          ${initQlueLS}
          ${initBlink}
        '';

        minimalLua = pkgs.writeText "init-minimal.lua" ''
          vim.opt.termguicolors = true
          ${loadCommon}
          vim.opt.rtp:prepend(vim.fn.getcwd())
          ${initQlueLS}
          ${initBlink}
        '';

        fzfLuaLua = pkgs.writeText "init-fzflua.lua" ''
          vim.opt.termguicolors = true
          ${loadFzfLua}
          vim.opt.rtp:prepend(vim.fn.getcwd())
          require('fzf-lua').setup()
          ${initQlueLS}
          ${initBlink}
        '';

        # B. Create the Executables in the Nix Store
        # pkgs.writeShellScriptBin creates a 'bin/name' wrapper. 
        # We also move the isolation env vars HERE, so the binary is robust
        # even if you run it outside the direnv shell.

        nvimTelescope = pkgs.writeShellScriptBin "nvim-telescope" ''
          # 1. Isolate State to the project directory
          export NVIM_APPNAME="nvim-telescope"
          export XDG_CONFIG_HOME="$PWD/.dev-env/config"
          export XDG_DATA_HOME="$PWD/.dev-env/data"
          export XDG_STATE_HOME="$PWD/.dev-env/state"
          
          # 2. Launch Nvim with the specific config file from Nix Store
          exec ${pkgs.neovim}/bin/nvim -u "${telescopeLua}" "$@"
        '';

        nvimMinimal = pkgs.writeShellScriptBin "nvim-minimal" ''
          export NVIM_APPNAME="nvim-minimal"
          export XDG_CONFIG_HOME="$PWD/.dev-env/config"
          export XDG_DATA_HOME="$PWD/.dev-env/data"
          export XDG_STATE_HOME="$PWD/.dev-env/state"
          
          exec ${pkgs.neovim}/bin/nvim -u "${minimalLua}" "$@"
        '';

        nvimFzfLua = pkgs.writeShellScriptBin "nvim-fzf" ''
          export NVIM_APPNAME="nvim-fzf"
          export XDG_CONFIG_HOME="$PWD/.dev-env/config"
          export XDG_DATA_HOME="$PWD/.dev-env/data"
          export XDG_STATE_HOME="$PWD/.dev-env/state"
          
          exec ${pkgs.neovim}/bin/nvim -u "${fzfLuaLua}" "$@"
        '';
 

        # --- 5. RUST APP ---
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
          # We add our custom binaries to the packages list.
          # Nix puts them in $PATH automatically.
          packages = [
            pkgs.neovim
            pkgs.luarocks
            lua
            qlue-ls-pkg
            nvimTelescope
            nvimMinimal
            nvimFzfLua
          ];

          # ShellHook is now purely for info, or creating dirs if you really want to.
          # The wrappers create their own XDG directories on the fly if needed.
          shellHook = ''
             echo "✅ Proper Nix Dev Env Loaded"
             echo "   - nvim-telescope"
             echo "   - nvim-minimal"
             echo "   - nvim-fzf"
          '';
        };
      }
    );
}
