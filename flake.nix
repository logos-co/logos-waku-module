{
  description = "Logos Waku Module";

  inputs = {
    # Follow the same nixpkgs as logos-liblogos to ensure compatibility
    nixpkgs.follows = "logos-liblogos/nixpkgs";
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

          libwakuLib = if pkgs.stdenv.hostPlatform.isDarwin then "libwaku.dylib" else "libwaku.so";
          
          cmakeFlags = [ 
            "-GNinja"
            "-DLOGOS_CPP_SDK_ROOT=${logosSdk}"
            "-DLOGOS_LIBLOGOS_ROOT=${logosLiblogos}"
            "-DLOGOS_WAKU_MODULE_USE_VENDOR=OFF"
          ];
          
          # Set environment variables for CMake to find the dependencies
          LOGOS_CPP_SDK_ROOT = "${logosSdk}";
          LOGOS_LIBLOGOS_ROOT = "${logosLiblogos}";
          
          # Copy libwaku library (dylib or so) and plugin to the result directory
          postInstall = ''
            mkdir -p $out/lib
            
            # Copy libwaku library
            srcLib="$src/lib/${libwakuLib}"
            if [ ! -f "$srcLib" ]; then
              echo "Expected ${libwakuLib} in $src/lib/" >&2
              exit 1
            fi
            cp "$srcLib" "$out/lib/"
            
            # Copy the waku module plugin (already installed by cmake to lib/logos/modules)
            if [ -f "$out/lib/logos/modules/waku_module_plugin.dylib" ]; then
              cp "$out/lib/logos/modules/waku_module_plugin.dylib" "$out/lib/"
            elif [ -f "$out/lib/logos/modules/waku_module_plugin.so" ]; then
              cp "$out/lib/logos/modules/waku_module_plugin.so" "$out/lib/"
            fi
            
            # Remove the nested structure we don't want
            rm -rf "$out/lib/logos" 2>/dev/null || true
            rm -rf "$out/share" 2>/dev/null || true
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

