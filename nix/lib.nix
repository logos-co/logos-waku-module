# Builds the logos-waku-module library
{ pkgs, common, src, logosDelivery }:

pkgs.stdenv.mkDerivation {
  pname = "${common.pname}-lib";
  version = common.version;

  inherit src;
  inherit (common) nativeBuildInputs buildInputs cmakeFlags meta env;

  # Determine platform-specific library extension
  libwakuLib = if pkgs.stdenv.hostPlatform.isDarwin then "libwaku.dylib" else "libwaku.so";
  libpqPattern = if pkgs.stdenv.hostPlatform.isDarwin then "libpq*.dylib" else "libpq.so*";

  postInstall = ''
    mkdir -p $out/lib

    # Copy libpq from PostgreSQL so it ships with the module runtime libs
    for pq in ${pkgs.lib.getLib pkgs.postgresql}/lib/''${libpqPattern}; do
      if [ -e "$pq" ]; then
        cp -L "$pq" "$out/lib/$(basename "$pq")"
      fi
    done

    # Normalize libpq naming for runtime loaders
    if [ -f "$out/lib/libpq.5.dylib" ] && [ ! -e "$out/lib/libpq.dylib" ]; then
      ln -s libpq.5.dylib "$out/lib/libpq.dylib"
    fi

    if [ -f "$out/lib/libpq.so.5" ] && [ ! -e "$out/lib/libpq.so" ]; then
      ln -s libpq.so.5 "$out/lib/libpq.so"
    fi

    # Copy libwaku directly from the logos-delivery package
    if [ -f "${logosDelivery}/bin/''${libwakuLib}" ]; then
        cp "${logosDelivery}/bin/''${libwakuLib}" "$out/lib/''${libwakuLib}"
    elif [ -f "$out/share/logos-waku-module/generated/''${libwakuLib}" ]; then
        cp "$out/share/logos-waku-module/generated/''${libwakuLib}" "$out/lib/''${libwakuLib}"
    fi

    # Fix the install name of libwaku on macOS
    ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      if [ -f "$out/lib/''${libwakuLib}" ]; then
        ${pkgs.darwin.cctools}/bin/install_name_tool -id "@rpath/''${libwakuLib}" "$out/lib/''${libwakuLib}"
        # Ensure @rpath lookups resolve against the library's own directory
        ${pkgs.darwin.cctools}/bin/install_name_tool -add_rpath "@loader_path" "$out/lib/''${libwakuLib}" 2>/dev/null || true
      fi

      if [ -f "$out/lib/libpq.dylib" ]; then
        ${pkgs.darwin.cctools}/bin/install_name_tool -id "@loader_path/libpq.dylib" "$out/lib/libpq.dylib" 2>/dev/null || true
      fi

      if [ -f "$out/lib/libpq.5.dylib" ]; then
        ${pkgs.darwin.cctools}/bin/install_name_tool -id "@loader_path/libpq.5.dylib" "$out/lib/libpq.5.dylib" 2>/dev/null || true
      fi
    ''}

    # Ensure Linux runtime lookup can find adjacent shared libraries
    ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      if [ -f "$out/lib/''${libwakuLib}" ]; then
        chmod 755 -R $out/lib
        ${pkgs.patchelf}/bin/patchelf --set-rpath '$ORIGIN' "$out/lib/''${libwakuLib}"
        ${pkgs.patchelf}/bin/patchelf --add-needed libpq.so.5 "$out/lib/''${libwakuLib}" 2>/dev/null || true
      fi
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

        # Ensure plugin resolves @rpath entries from its own location
        ${pkgs.darwin.cctools}/bin/install_name_tool -add_rpath "@loader_path" "$out/lib/waku_module_plugin.dylib" 2>/dev/null || true

        # If plugin references libpq directly, make it resolve next to the plugin
        for dep in $(${pkgs.darwin.cctools}/bin/otool -L "$out/lib/waku_module_plugin.dylib" | grep libpq | awk '{print $1}'); do
          ${pkgs.darwin.cctools}/bin/install_name_tool -change "$dep" "@loader_path/libpq.dylib" "$out/lib/waku_module_plugin.dylib" 2>/dev/null || true
        done
      ''}
    elif [ -f "$out/lib/logos/modules/waku_module_plugin.so" ]; then
      cp "$out/lib/logos/modules/waku_module_plugin.so" "$out/lib/"

      ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
        ${pkgs.patchelf}/bin/patchelf --set-rpath '$ORIGIN' "$out/lib/waku_module_plugin.so"
        ${pkgs.patchelf}/bin/patchelf --add-needed libpq.so.5 "$out/lib/waku_module_plugin.so" 2>/dev/null || true
      ''}
    else
      echo "Error: No waku_module_plugin library file found"
      exit 1
    fi

    # Remove the nested structure we don't want
    rm -rf "$out/lib/logos" 2>/dev/null || true
    rm -rf "$out/share" 2>/dev/null || true

    # Assert runtime packaging/fixups are in place
    if [ ! -e "$out/lib/libpq.dylib" ] && [ ! -e "$out/lib/libpq.so" ] && [ ! -e "$out/lib/libpq.so.5" ]; then
      echo "Error: libpq was not packaged into $out/lib"
      exit 1
    fi

    ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
      if [ ! -f "$out/lib/libwaku.dylib" ]; then
        echo "Error: libwaku.dylib missing"
        exit 1
      fi

      if ! ${pkgs.darwin.cctools}/bin/otool -l "$out/lib/libwaku.dylib" | grep -A2 LC_RPATH | grep -q '@loader_path'; then
        echo "Error: libwaku.dylib is missing LC_RPATH @loader_path"
        exit 1
      fi

      if [ -f "$out/lib/libpq.dylib" ] && ! ${pkgs.darwin.cctools}/bin/otool -D "$out/lib/libpq.dylib" | grep -q '@loader_path/libpq.dylib'; then
        echo "Error: libpq.dylib install id is not @loader_path/libpq.dylib"
        exit 1
      fi
    ''}

    ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
      if [ ! -f "$out/lib/libwaku.so" ]; then
        echo "Error: libwaku.so missing"
        exit 1
      fi

      if [ "$(${pkgs.patchelf}/bin/patchelf --print-rpath "$out/lib/libwaku.so")" != '$ORIGIN' ]; then
        echo "Error: libwaku.so rpath is not $ORIGIN"
        exit 1
      fi

      if ! ${pkgs.patchelf}/bin/patchelf --print-needed "$out/lib/libwaku.so" | grep -q '^libpq\.so\.5$'; then
        echo "Error: libwaku.so is missing NEEDED libpq.so.5"
        exit 1
      fi
    ''}
  '';
}

