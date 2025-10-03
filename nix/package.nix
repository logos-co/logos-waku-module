{ lib
, stdenv
, cmake
, ninja
, pkg-config
, qt6
, gnumake
, nim
, openssl
, libsodium
, pcre
, zlib
, logosLiblogosSrc
, logosCppSdkSrc
, nwakuSrc
}:

let
  qtDeps = [
    qt6.qtbase
    qt6.qtremoteobjects
  ];
  qtPrefixPath = lib.concatStringsSep ";" (map (pkg: "${pkg}") qtDeps);
in
stdenv.mkDerivation {
  pname = "logos-waku-module";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      let
        base = toString ../.;
        pathStr = toString path;
        relPath = lib.removePrefix (base + "/") pathStr;
        excludeVendor = !(lib.hasPrefix "vendor/" relPath);
      in
        lib.cleanSourceFilter path type && excludeVendor;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
    gnumake
    nim
  ];

  buildInputs = qtDeps ++ [
    openssl
    libsodium
    pcre
    zlib
  ];

  cmakeBuildType = "Release";

  dontWrapQtApps = true;

  postUnpack = ''
    echo "Replacing vendor dependencies with flake inputs"
    rm -rf source/vendor/logos-liblogos source/vendor/logos-cpp-sdk source/vendor/nwaku
    mkdir -p source/vendor
    cp -r ${logosLiblogosSrc} source/vendor/logos-liblogos
    cp -r ${logosCppSdkSrc} source/vendor/logos-cpp-sdk
    cp -r ${nwakuSrc} source/vendor/nwaku
    chmod -R u+w source/vendor/logos-liblogos source/vendor/logos-cpp-sdk source/vendor/nwaku
  '';

  preConfigure = ''
    echo "Building libwaku via vendored nwaku"
    export USE_SYSTEM_NIM=1
    cd vendor/nwaku
    make libwaku
    cd ../..

    mkdir -p lib
    cp vendor/nwaku/build/libwaku.* lib/ 2>/dev/null || true
    if [ -f vendor/nwaku/library/libwaku.h ]; then
      cp vendor/nwaku/library/libwaku.h lib/libwaku.h
    fi
  '';

  cmakeFlags = [
    "-GNinja"
    "-DLOGOS_WAKU_MODULE_USE_VENDOR=ON"
  ];

  CMAKE_PREFIX_PATH = qtPrefixPath;
  QT_DIR = qtPrefixPath;

  meta = with lib; {
    description = "Waku Logos module plugin";
    platforms = platforms.unix;
  };
}

