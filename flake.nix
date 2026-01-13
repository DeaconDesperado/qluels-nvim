{
  description = "Development environment for qluels-nvim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

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
            lua
            pkgs.luarocks
          ];

          shellHook = ''
            echo "qluels-nvim development environment"
            echo "Lua: $(lua -v)"
            echo "Packages available: busted, nlua, plenary.nvim"
            echo ""
            echo "Run tests with: busted tests/"
          '';
        };
      }
    );
}
