{
  description = "Logos Waku Module";

  inputs = {
    # Follow the same nixpkgs as logos-liblogos to ensure compatibility
    nixpkgs.follows = "logos-liblogos/nixpkgs";
    logos-cpp-sdk.url = "github:logos-co/logos-cpp-sdk?ref=feat/logos-result";
    logos-liblogos.url = "github:logos-co/logos-liblogos";
    logos-delivery.url =
      "git+https://github.com/logos-messaging/logos-delivery?submodules=1";
  };

  outputs = { self, nixpkgs, logos-cpp-sdk, logos-liblogos, logos-delivery }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        logosSdk = logos-cpp-sdk.packages.${system}.default;
        logosLiblogos = logos-liblogos.packages.${system}.default;
        logosDelivery = logos-delivery.packages.${system}.libwaku;
      });
    in
    {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosDelivery }:
        let
          # Common configuration
          common = import ./nix/default.nix { inherit pkgs logosSdk logosLiblogos logosDelivery; };
          src = ./.;

          # Library package (plugin + libwaku)
          lib = import ./nix/lib.nix { inherit pkgs common src logosDelivery; };

          # Include package (generated headers from plugin)
          include = import ./nix/include.nix { inherit pkgs common src lib logosSdk logosDelivery; };

          # Combined package
          combined = pkgs.symlinkJoin {
            name = "logos-waku-module";
            paths = [ lib include ];
          };
        in
        {
          # Individual outputs
          logos-waku-module-lib = lib;
          logos-waku-module-include = include;
          lib = lib;

          # Default package (combined)
          default = combined;
        }
      );

      devShells = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosDelivery }: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.cmake
            pkgs.ninja
            pkgs.pkg-config
          ];
          buildInputs = [
            pkgs.qt6.qtbase
            pkgs.qt6.qtremoteobjects
          ];

          shellHook = ''
            export LOGOS_CPP_SDK_ROOT="${logosSdk}"
            export LOGOS_LIBLOGOS_ROOT="${logosLiblogos}"
            export LOGOS_DELIVERY_ROOT="${logosDelivery}"
            echo "Logos Waku Module development environment"
            echo "LOGOS_CPP_SDK_ROOT: $LOGOS_CPP_SDK_ROOT"
            echo "LOGOS_LIBLOGOS_ROOT: $LOGOS_LIBLOGOS_ROOT"
            echo "LOGOS_DELIVERY_ROOT: $LOGOS_DELIVERY_ROOT"
          '';
        };
      });
    };
}
