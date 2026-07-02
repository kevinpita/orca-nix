{
  description = "Nix flake for Orca, the ADE for working with a fleet of parallel agents";

  nixConfig = {
    extra-substituters = [ "https://kevinpita.cachix.org" ];
    extra-trusted-public-keys = [
      "kevinpita.cachix.org-1:Cu9UtCDSfDq3/WDnI7N1N/LzAh90SPS+1R+nWao/hz0="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { nixpkgs, flake-utils, ... }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      overlay = final: prev: {
        orca = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachSystem supportedSystems
      (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          packages = {
            default = pkgs.orca;
            orca = pkgs.orca;
          };

          apps = {
            default = {
              type = "app";
              program = "${pkgs.orca}/bin/orca-ide";
            };
            orca = {
              type = "app";
              program = "${pkgs.orca}/bin/orca";
            };
            orca-ide = {
              type = "app";
              program = "${pkgs.orca}/bin/orca-ide";
            };
          };

          formatter = pkgs.nixpkgs-fmt;

          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              curl
              gh
              jq
              nixpkgs-fmt
            ];
          };
        }
      )
    // {
      overlays.default = overlay;
    };
}
