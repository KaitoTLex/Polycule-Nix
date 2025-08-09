{
  description = "Polycule Matrix client with updated libolm, built reproducibly in Nix";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          # ---- libolm: latest secure build ----
          libolm = pkgs.stdenv.mkDerivation rec {
            pname = "olm";
            version = "3.2.16";

            src = pkgs.fetchgit {
              url = "https://gitlab.matrix.org/matrix-org/olm.git";
              rev = "6d4b5b07887821a95b144091c8497d09d377f985";
              sha256 = "sha256-AcmOf91dG/2AIQeNJ8m/+4t1MdKYMBFBntHp2ppFJzg=";
            };

            nativeBuildInputs = [
              pkgs.cmake
              pkgs.python3
            ];

            cmakeFlags = [
              "-DBUILD_SHARED_LIBS=OFF"
              "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
            ];

            meta = with pkgs.lib; {
              description = "Implementation of the Double Ratchet cryptographic ratchet";
              homepage = "https://gitlab.matrix.org/matrix-org/olm";
              license = licenses.bsd3;
              platforms = platforms.linux;
            };
          };

          # ---- polycule: Flutter build ----
          polycule = pkgs.stdenv.mkDerivation rec {
            pname = "polycule";
            version = "0.2.5";

            src = pkgs.fetchgit {
              url = "https://gitlab.com/polycule_client/polycule.git";
              rev = "v0.2.5";
              sha256 = "sha256-KaMgItnb+pRHKgK+a6uf//zv4yMbSIgXTyZdXjOCGBY=";
            };

            # Flutter only — no cmake here to avoid Nix's cmake build phase
            nativeBuildInputs = [ pkgs.flutter ];

            buildInputs = [
              pkgs.dbus
              pkgs.gtk3
              pkgs.libnotify
              libolm
              pkgs.libsecret
              pkgs.mimalloc
              pkgs.mpv
              pkgs.openssl
              pkgs.xdg-user-dirs
            ];

            dontConfigure = true; # Skip Nix's default configurePhase

            preBuild = ''
              export HOME=$TMPDIR
              export PATH="${pkgs.flutter}/bin:$PATH"
              export PUB_CACHE=$TMPDIR/.pub-cache
              export FLUTTER_ROOT=${pkgs.flutter}/lib/flutter
              export CI="true"

              mkdir -p $PUB_CACHE $TMPDIR/.flutter
              echo "no-analytics" > $TMPDIR/.flutter/analytics_disabled

              flutter config --enable-linux-desktop
            '';

            buildPhase = ''
              runHook preBuild
              flutter pub get
              flutter build linux --release --no-version-check
            '';

            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              cp build/linux/release/bundle/polycule $out/bin/polycule
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "A geeky and efficient Matrix client for power users";
              homepage = "https://gitlab.com/polycule_client/polycule";
              license = licenses.eupl12;
              platforms = platforms.linux;
            };
          };

        in
        {
          inherit libolm polycule;
          default = polycule;
        }
      );

      defaultPackage = forAllSystems (system: self.packages.${system}.default);

      # Optional devShell for hacking
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.mkShell {
          buildInputs = [
            pkgs.flutter
            pkgs.cmake
            pkgs.pkg-config
            pkgs.dbus
            pkgs.gtk3
            pkgs.libnotify
            pkgs.libsecret
            pkgs.openssl
          ];
        }
      );
    };
}
