{
  description = "Build the Logos waku module with Nix";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
  inputs.nwaku = {
    url = "git+https://github.com/iurimatias/nwaku.git?ref=template_fix&submodules=1";
    flake = false;
  };

  outputs = { self, nixpkgs, nwaku }:
    let
      lib = nixpkgs.lib;
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forSystems = f: lib.genAttrs systems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
          f pkgs
      );
    in
    {
      packages = forSystems (pkgs: {
        default = pkgs.stdenv.mkDerivation {
          name = "libwaku";
          src = ./.;
          
          # Disable automatic cmake configuration - we'll handle the build ourselves
          dontUseCmakeConfigure = true;
          dontConfigure = true;

          nativeBuildInputs = with pkgs; [
            gnumake
            git
            which
            nim
            gcc
            pkg-config
            rustc
            cargo
            darwin.ps
            bash
            coreutils
            pcre
            sqlite
            openssl
            cmake
            libtool
            darwin.cctools
            curl
            jq
          ];
          
          buildInputs = with pkgs; [
            openssl
            sqlite
            pcre
          ];

          buildPhase = ''
            # Create vendor directory and copy nwaku (needs to be writable for build)
            mkdir -p vendor
            cp -r ${nwaku} vendor/nwaku
            chmod -R u+w vendor/nwaku
            
            # Copy the prebuilt librln file if it exists in the source
            # (The nwaku submodule might not include it due to .gitignore)
            if [ -f "${./.}/vendor/nwaku/librln_v0.5.1.a" ]; then
              cp "${./.}/vendor/nwaku/librln_v0.5.1.a" vendor/nwaku/
            fi
            
            # Create a stub sysctl to satisfy the build system
            mkdir -p $TMPDIR/bin
            cat > $TMPDIR/bin/sysctl <<'EOF'
            #!/bin/sh
            # Stub sysctl for Nix build
            if [ "$1" = "-n" ] && [ "$2" = "hw.ncpu" ]; then
              echo "8"
            elif [ "$1" = "-n" ] && [ "$2" = "hw.physicalcpu" ]; then
              echo "8"
            else
              echo "unknown"
            fi
            EOF
            chmod +x $TMPDIR/bin/sysctl
            export PATH=$TMPDIR/bin:$PATH
            
            # Initialize git repo to satisfy Makefile's git checks
            cd vendor/nwaku
            git init
            git config user.email "nix@build"
            git config user.name "Nix Build"
            git add -A
            git commit -m "Initial commit for build"
            
            # Set up environment for build
            export HOME=$TMPDIR
            export NIMBLE_DIR=$TMPDIR/.nimble
            mkdir -p $NIMBLE_DIR
            
            # Create wrapper for libtool that converts calls to ar
            # The Makefile tries to use "libtool -static -o output input" on macOS
            # but we want to use "ar crs output input" instead
            mkdir -p $TMPDIR/wrappers
            cat > $TMPDIR/wrappers/libtool <<'LIBTOOLWRAPPER'
            #!/bin/sh
            # Wrapper to convert libtool -static calls to ar calls
            if [ "$1" = "-static" ]; then
              shift
              if [ "$1" = "-o" ]; then
                output="$2"
                shift 2
                exec ar crs "$output" "$@"
              fi
            fi
            # Fallback to ar for other cases
            exec ar crs "$@"
            LIBTOOLWRAPPER
            chmod +x $TMPDIR/wrappers/libtool
            export PATH=$TMPDIR/wrappers:$PATH
            
            # Create the expected Nim directory structure with a wrapper script
            # This makes the build system think Nim is already built
            NIM_DIR="vendor/nimbus-build-system/vendor/Nim"
            mkdir -p "$NIM_DIR/bin"
            
            # Create a wrapper script that calls the system nim
            cat > "$NIM_DIR/bin/nim" <<NIMWRAPPER
            #!/bin/sh
            exec "$(which nim)" "\$@"
            NIMWRAPPER
            chmod +x "$NIM_DIR/bin/nim"
            
            # Patch the targets.mk to skip building nim
            # Override the build-nim target to do nothing
            echo "" >> vendor/nimbus-build-system/makefiles/targets.mk
            echo "# Patched by Nix build to use system Nim" >> vendor/nimbus-build-system/makefiles/targets.mk
            echo "build-nim:" >> vendor/nimbus-build-system/makefiles/targets.mk
            echo "	@echo 'Using system Nim, skipping build'" >> vendor/nimbus-build-system/makefiles/targets.mk
            
            # Build libwaku (disable libbacktrace since it's optional and failing to build)
            make libwaku USE_LIBBACKTRACE=0
          '';

          installPhase = ''
            mkdir -p $out/lib
            cp build/libwaku* $out/lib/ || true
          '';
        };
      });

      devShells = forSystems (pkgs: {
        default = pkgs.mkShell {
          nativeBuildInputs = [
            pkgs.gnumake
          ];
        };
      });
    };
}
