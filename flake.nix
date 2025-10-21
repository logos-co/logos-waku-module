{
  description = "Logos Waku Module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    logos-cpp-sdk.url = "github:logos-co/logos-cpp-sdk";
    logos-liblogos.url = "github:logos-co/logos-liblogos";
  };

  outputs = { self, nixpkgs, logos-cpp-sdk, logos-liblogos }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        logosSdk = logos-cpp-sdk.packages.${system}.default;
        logosLiblogos = logos-liblogos.packages.${system}.default;
      });
    in
    {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos }: {
        default = pkgs.stdenv.mkDerivation rec {
          pname = "logos-waku-module";
          version = "1.0.0";
          
          src = ./.;
          
          nativeBuildInputs = [ 
            pkgs.cmake 
            pkgs.ninja 
            pkgs.pkg-config
            pkgs.qt6.wrapQtAppsNoGuiHook
          ];
          
          buildInputs = [ 
            pkgs.qt6.qtbase 
            pkgs.qt6.qtremoteobjects 
            logosSdk
            logosLiblogos
          ];
          
          cmakeFlags = [ 
            "-GNinja"
            "-DLOGOS_CPP_SDK_ROOT=${logosSdk}"
            "-DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}"
            "-DLOGOS_WAKU_MODULE_USE_VENDOR=OFF"
          ];
          
          # Set environment variables for CMake to find the dependencies
          LOGOS_CPP_SDK_ROOT = "${logosSdk}";
          LOGOS_LIBLOGOS_ROOT = "${logosLiblogos}";
          
          # Copy libwaku.so to the result directory
          postInstall = ''
            mkdir -p $out/lib/logos/modules
            cp $src/lib/libwaku.so $out/lib/logos/modules/
          '';
          
          meta = with pkgs.lib; {
            description = "Logos Waku Module - Provides Waku network communication capabilities";
            platforms = platforms.unix;
          };
        };
      });

      devShells = forAllSystems ({ pkgs, logosSdk, logosLiblogos }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
            logosSdk
            logosLiblogos
          ];
          
          shellHook = ''
            export LOGOS_CPP_SDK_ROOT="${logosSdk}"
            export LOGOS_LIBLOGOS_ROOT="${logosLiblogos}"
            echo "Logos Waku Module development environment"
            echo "LOGOS_CPP_SDK_ROOT: $LOGOS_CPP_SDK_ROOT"
            echo "LOGOS_LIBLOGOS_ROOT: $LOGOS_LIBLOGOS_ROOT"
          '';
        };
      });
    };
}

