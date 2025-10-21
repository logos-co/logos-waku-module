#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="${SCRIPT_DIR}/vendor/nwaku"
LIB_DIR="${SCRIPT_DIR}/lib"

DEFAULT_JOBS=$(command -v getconf >/dev/null 2>&1 && getconf _NPROCESSORS_ONLN 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)
JOBS="${JOBS:-${DEFAULT_JOBS}}"
CLEAN_FIRST=0

usage() {
    cat <<'EOF'
Usage: build_libwaku.sh [--jobs N] [--clean]

Initialises the vendored nwaku submodule (if required) and builds libwaku.
  --jobs, -j N  Parallel build jobs (default: detected CPU count)
  --clean       Remove previous build artifacts before building
  -h, --help    Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --jobs|-j)
            if [[ $# -lt 2 ]]; then
                echo "--jobs requires a numeric argument" >&2
                exit 1
            fi
            JOBS="$2"
            shift 2
            ;;
        --clean)
            CLEAN_FIRST=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ ! -d "${VENDOR_DIR}" ]]; then
    echo "Fetching nwaku submodule..."
    git -C "${SCRIPT_DIR}" submodule update --init --recursive vendor/nwaku
fi

if [[ ! -d "${VENDOR_DIR}" ]]; then
    echo "Error: vendor/nwaku directory not available" >&2
    exit 1
fi

if [[ ${CLEAN_FIRST} -eq 1 ]]; then
    echo "Cleaning previous libwaku artifacts"
    rm -rf "${VENDOR_DIR}/build"
    rm -rf "${LIB_DIR}"
fi

mkdir -p "${LIB_DIR}"

echo "Ensuring nwaku nested submodules are available..."
git -C "${VENDOR_DIR}" submodule update --init --recursive

echo "Building libwaku with ${JOBS} jobs..."
(
    cd "${VENDOR_DIR}"
    export USE_SYSTEM_NIM=${USE_SYSTEM_NIM:-1}
    make -j"${JOBS}" libwaku
)

echo "Copying libwaku artifacts into ${LIB_DIR}"
shopt -s nullglob
for artifact in "${VENDOR_DIR}/build"/libwaku.*; do
    basename_artifact=$(basename "${artifact}")
    # Detect platform and rename library file accordingly
    case "$(uname -s)" in
        Darwin*)
            # macOS - rename .so to .dylib
            if [[ "${basename_artifact}" == "libwaku.so" ]]; then
                cp "${artifact}" "${LIB_DIR}/libwaku.dylib"
            else
                cp "${artifact}" "${LIB_DIR}/${basename_artifact}"
            fi
            ;;
        Linux*)
            # Linux - keep .so extension
            cp "${artifact}" "${LIB_DIR}/${basename_artifact}"
            ;;
        *)
            # Other platforms - keep original name
            cp "${artifact}" "${LIB_DIR}/${basename_artifact}"
            ;;
    esac
done
shopt -u nullglob

if [[ -f "${VENDOR_DIR}/library/libwaku.h" ]]; then
    cp "${VENDOR_DIR}/library/libwaku.h" "${LIB_DIR}/libwaku.h"
fi

echo "libwaku build complete"
