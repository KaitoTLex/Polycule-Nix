{
  description = "Polycule C++ Matrix client with Rust vodozemac dependency";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      naersk,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = false;
        };

        naerskLib = naersk.lib.${system};

        # Build vodozemac
        vodozemac = naerskLib.buildPackage {
          pname = "vodozemac";
          version = "24a674d840270eeb7c0709ab28d3a4bf87f192c4";

          src = pkgs.fetchFromGitHub {
            owner = "KaitoTLex";
            repo = "vodozemac";
            rev = "24a674d840270eeb7c0709ab28d3a4bf87f192c4";
            sha256 = "sha256-5wPfG2OUomh3bEjcemfvirKCeAimXjFApIRcZkFOn2A=";
          };
          # Typical Rust build inputs:
          buildInputs = with pkgs; [
            cargo
            clang
            openssl
          ];

          # Optionally, specify cargo build flags (e.g., release):
          cargoBuildFlags = [ "--no-default-features" ];
        };

        # Build Polycule (C++/Qt)
        polycule = pkgs.stdenv.mkDerivation {
          pname = "polycule";
          version = "0.1.0";

          src = pkgs.fetchFromGitLab {
            owner = "polycule_client";
            repo = "polycule";
            rev = "5419506348ae86e7c58bc9d9f591a74744a73ea4";
            sha256 = "sha256-JC+YLRZg/2VM1MYBYr2engIE1f5+3slDFyUfis+uYmI=";
          };

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
            qt5.qtbase
          ];

          buildInputs = [
            # Ensure Polycule can link to vodozemac
            vodozemac
          ];

          # Give CMake or pkg-config the path to find vodozemac:
          configureFlags = [
            "-DCMAKE_PREFIX_PATH=${vodozemac}"
          ];

          # Or if Polycule uses pkg-config:
          # shellEnv = {
          #   PKG_CONFIG_PATH = "${vodozemac}/lib/pkgconfig";
          # };

          # Standard phases follow
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            cmake
            pkg-config
            qt5.qtbase
            rustc
            cargo
          ];
        };

      in
      {
        packages.default = polycule;
        devShells.default = devShell;
      }
    );
}
