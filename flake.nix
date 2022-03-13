{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix-src.url = github:jmgilman/poetry2nix;
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        devPkgs = [
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.nodePackages.markdownlint-cli
        ];
      in {
        devShell = pkgs.mkShell {
          packages = devPkgs;
        };
      }
    );
}