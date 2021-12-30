# This file is pretty general, and you can adapt it in your project replacing
# only `name` and `description` below.

{
  description = "Infrastructure configuration CLI";

  inputs = {
    nixpkgs.url = "github:vkleen/nixpkgs/local";
    utils.url = "github:numtide/flake-utils";
    rust-overlay.url = "github:oxalica/rust-overlay";
    crate2nix = {
      url = "github:kolloch/crate2nix";
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, utils, rust-overlay, crate2nix, ... }:
    let
      name = "infraconf";
      rustChannel = "nightly";
    in
    utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [
              rust-overlay.overlay
              (final: prev: let
                rust = final.rust-bin.nightly.latest.default.override {
                  extensions = [ "rust-src" "llvm-tools-preview" "rust-analyzer-preview" ];
                  targets = [  ];
                };
              in {

                # Because rust-overlay bundles multiple rust packages into one
                # derivation, specify that mega-bundle here, so that crate2nix
                # will use them automatically.
                rustc = rust;
                cargo = rust;
              })
            ];
          };
          inherit (import "${crate2nix}/tools.nix" { inherit pkgs; })
            generatedCargoNix;

          # Create the cargo2nix project
          project = import
            (generatedCargoNix {
              inherit name;
              src = ./.;
            })
            {
              nixpkgs = nixpkgs.legacyPackages.${system}.path;
              inherit pkgs;
              # Individual crate overrides go here
              # Example: https://github.com/balsoft/simple-osd-daemons/blob/6f85144934c0c1382c7a4d3a2bbb80106776e270/flake.nix#L28-L50
              defaultCrateOverrides = pkgs.defaultCrateOverrides // {
                ${name} = oldAttrs: {
                  inherit buildInputs nativeBuildInputs;
                };
              };
            };

          buildInputs = with pkgs; [ ];
          nativeBuildInputs = with pkgs; [ rustc cargo pkgconfig ];
        in
        rec {
          packages.${name} = project.rootCrate.build;

          defaultPackage = packages.${name};

          apps.${name} = utils.lib.mkApp {
            inherit name;
            drv = packages.${name};
          };
          defaultApp = apps.${name};

          devShell = pkgs.mkShell
            {
              inputsFrom = builtins.attrValues self.packages.${system};
              buildInputs = buildInputs ++ (with pkgs;
                [
                  nixpkgs-fmt
                  cargo-watch
                  cargo-modules
                  cargo-expand
                  lldb
                ]);
              RUST_SRC_PATH = "${pkgs.rust-bin.${rustChannel}.latest.rust-src}/lib/rustlib/src/rust/library";
            };
        }
      );
}
