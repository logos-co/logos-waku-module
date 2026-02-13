# Builds the logos-waku-module library
# logosMessagingNim: the libwaku package from logos-messaging-nim flake (poc/logos-testnet-mix branch)
{ pkgs, common, src, logosMessagingNim }:

pkgs.stdenv.mkDerivation {
  pname = "${common.pname}-lib";
  version = common.version;

  inherit src;
  inherit (common) nativeBuildInputs buildInputs cmakeFlags meta env;

  # Determine platform-specific library extension
  libwakuLib = if pkgs.stdenv.hostPlatform.isDarwin then "libwaku.dylib" else "libwaku.so";

  # Copy libwaku from logos-messaging-nim into lib/ before CMake configure
  preConfigure = ''
    runHook prePreConfigure

    mkdir -p lib

    # logos-messaging-nim installs the built library into $out/bin/
    srcLib="${logosMessagingNim}/bin/''${libwakuLib}"
    if [ ! -f "$srcLib" ]; then
      echo "Expected ''${libwakuLib} in ${logosMessagingNim}/bin/" >&2
      echo "Contents of ${logosMessagingNim}/bin/:"
      ls -la "${logosMessagingNim}/bin/" 2>/dev/null || echo "bin/ directory does not exist"
      exit 1
    fi
    cp "$srcLib" lib/
    chmod u+w lib/''${libwakuLib}

    # Copy the header file if available
    if [ -f "${logosMessagingNim}/include/libwaku.h" ]; then
      cp "${logosMessagingNim}/include/libwaku.h" lib/
      chmod u+w lib/libwaku.h
    fi

    echo "Copied libwaku from logos-messaging-nim into lib/:"
    ls -la lib/

    runHook postPreConfigure
  '';

  postInstall = ''
    mkdir -p $out/lib

    # Copy libwaku library directly from logos-messaging-nim output
    cp "${logosMessagingNim}/bin/''${libwakuLib}" "$out/lib/"
    chmod u+w "$out/lib/''${libwakuLib}"

    # Fix the install name of libwaku on macOS
    ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      ${pkgs.darwin.cctools}/bin/install_name_tool -id "@rpath/''${libwakuLib}" "$out/lib/''${libwakuLib}"
    ''}

    # Copy the waku module plugin from the installed location
    if [ -f "$out/lib/logos/modules/waku_module_plugin.dylib" ]; then
      cp "$out/lib/logos/modules/waku_module_plugin.dylib" "$out/lib/"

      # Fix the plugin's reference to libwaku on macOS
      ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
        # Find what libwaku path the plugin is referencing and change it to @rpath
        for dep in $(${pkgs.darwin.cctools}/bin/otool -L "$out/lib/waku_module_plugin.dylib" | grep libwaku | awk '{print $1}'); do
          ${pkgs.darwin.cctools}/bin/install_name_tool -change "$dep" "@rpath/''${libwakuLib}" "$out/lib/waku_module_plugin.dylib"
        done
      ''}
    elif [ -f "$out/lib/logos/modules/waku_module_plugin.so" ]; then
      cp "$out/lib/logos/modules/waku_module_plugin.so" "$out/lib/"
    else
      echo "Error: No waku_module_plugin library file found"
      exit 1
    fi

    # Remove the nested structure we don't want
    rm -rf "$out/lib/logos" 2>/dev/null || true
    rm -rf "$out/share" 2>/dev/null || true
  '';
}

