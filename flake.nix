{
  description = "Development environment for qluels-nvim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "aarch64-darwin";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          lua5_1
          luarocks
        ];

        shellHook = ''
          echo "qluels-nvim development environment"
          echo "Lua: $(lua -v)"
          echo "LuaRocks: $(luarocks --version | head -n 1)"
        '';
      };
    };
}
