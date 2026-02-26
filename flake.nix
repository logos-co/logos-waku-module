{
  description = "Logos Waku Module";

  inputs = {
    # Follow the same nixpkgs as logos-liblogos to ensure compatibility
    nixpkgs.follows = "logos-liblogos/nixpkgs";
    logos-cpp-sdk.url = "github:logos-co/logos-cpp-sdk";
    logos-liblogos.url = "github:logos-co/logos-liblogos";
    # logos-messaging-nim: branch poc/logos-testnet-mix
    # Uses git+https (not github:) because the build needs submodules,
    # and github: type fetches tarballs which don't include submodule content.
    logos-messaging-nim = {
      url = "git+https://github.com/logos-messaging/logos-delivery?ref=poc/logos-testnet-mix&submodules=1";
    };
  };

  outputs = { self, nixpkgs, logos-cpp-sdk, logos-liblogos, logos-messaging-nim }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        pkgs = import nixpkgs { inherit system; };
        logosSdk = logos-cpp-sdk.packages.${system}.default;
        logosLiblogos = logos-liblogos.packages.${system}.default;
        logosMessagingNim = (logos-messaging-nim.packages.${system}.libwaku).overrideAttrs (old: {
          NIMFLAGS = (old.NIMFLAGS or "") + " -d:chronicles_colors:none";
        });
      });
    in
    {
      packages = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosMessagingNim }:
        let
          # Common configuration
          common = import ./nix/default.nix { inherit pkgs logosSdk logosLiblogos; };
          src = ./.;

          # Library package (plugin + libwaku)
          lib = import ./nix/lib.nix { inherit pkgs common src logosMessagingNim; };
          
          # Include package (generated headers from plugin)
          include = import ./nix/include.nix { inherit pkgs common src lib logosSdk; };
          
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

      devShells = forAllSystems ({ pkgs, logosSdk, logosLiblogos, logosMessagingNim }: {
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
            echo "Logos Waku Module development environment"
            echo "LOGOS_CPP_SDK_ROOT: $LOGOS_CPP_SDK_ROOT"
            echo "LOGOS_LIBLOGOS_ROOT: $LOGOS_LIBLOGOS_ROOT"
          '';
        };
      });
    };
}
