#!/bin/bash
# install.sh - Install script for p4-bindist (P4 binary distribution)
# Target: Ubuntu 24.04 x86_64
#
# Usage:
#   sudo ./install.sh                    # Install to /usr/local (default)
#   sudo ./install.sh --prefix /opt/p4   # Install to custom prefix
#   sudo ./install.sh --uninstall        # Remove installed files

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="/usr/local"
UNINSTALL=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --prefix)
            PREFIX="$2"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        --help)
            echo "Usage: $0 [--prefix /path] [--uninstall]"
            echo ""
            echo "Options:"
            echo "  --prefix PATH   Install to PATH (default: /usr/local)"
            echo "  --uninstall     Remove previously installed files"
            echo "  --help          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage."
            exit 1
            ;;
    esac
done

# Check we're running on Ubuntu 24.04
check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" != "ubuntu" ] || [ "$VERSION_ID" != "24.04" ]; then
            echo "WARNING: This bindist was built for Ubuntu 24.04."
            echo "Detected: $ID $VERSION_ID"
            echo "It may not work correctly on this system."
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Runtime apt dependencies that simple_switch_grpc and simple_switch need.
# These are standard Ubuntu 24.04 packages.
RUNTIME_DEPS=(
    python3
    patchelf
    libboost-filesystem1.83.0
    libboost-program-options1.83.0
    libboost-thread1.83.0
    libgmp10
    libpcap0.8t64
    libprotobuf32t64
    libgrpc++1.51t64
    libgrpc29t64
    libabsl20220623t64
    libre2-10
    libcares2
)

install_runtime_deps() {
    echo "Installing runtime dependencies via apt..."
    apt-get update -qq
    apt-get install -y --no-install-recommends "${RUNTIME_DEPS[@]}"
    echo "Runtime dependencies installed."
}

do_install() {
    echo "Installing p4-bindist to ${PREFIX}..."

    # Create directories
    mkdir -p "${PREFIX}/bin"
    mkdir -p "${PREFIX}/lib/p4-bindist"
    mkdir -p "${PREFIX}/share/p4c"

    # Copy binaries
    cp -f "${SCRIPT_DIR}/bin/"* "${PREFIX}/bin/"

    # Copy bundled shared libraries to a dedicated directory (preserve symlinks)
    cp -a "${SCRIPT_DIR}/lib/"* "${PREFIX}/lib/p4-bindist/"

    # Copy share files
    cp -rf "${SCRIPT_DIR}/share/p4c/"* "${PREFIX}/share/p4c/"

    # Fix RPATHs to point to the actual install location
    for bin in simple_switch simple_switch_grpc; do
        if [ -f "${PREFIX}/bin/${bin}" ]; then
            patchelf --set-rpath "${PREFIX}/lib/p4-bindist" "${PREFIX}/bin/${bin}" 2>/dev/null || true
        fi
    done

    # Update linker cache
    echo "${PREFIX}/lib/p4-bindist" > /etc/ld.so.conf.d/p4-bindist.conf
    ldconfig

    # Save install manifest for uninstall
    MANIFEST="${PREFIX}/share/p4c/.p4-bindist-manifest"
    echo "${PREFIX}" > "${MANIFEST}"

    echo ""
    echo "Installation complete!"
    echo ""
    echo "Installed binaries:"
    echo "  p4c              - P4 compiler driver"
    echo "  p4c-bm2-ss       - P4 compiler for BMv2 simple_switch"
    echo "  simple_switch     - BMv2 software switch"
    echo "  simple_switch_grpc - BMv2 software switch with gRPC"
    echo "  simple_switch_CLI  - CLI for simple_switch"
    echo ""
    echo "Verify with:"
    echo "  p4c --version"
    echo "  simple_switch_grpc --version"
}

do_uninstall() {
    echo "Uninstalling p4-bindist from ${PREFIX}..."

    # Remove binaries
    for bin in p4c p4c-bm2-ss p4c-bm2-psa p4c-bm2-pna p4c-dpdk p4c-ebpf \
               p4c-ubpf p4c-pna-p4tc p4c-graphs p4test \
               simple_switch simple_switch_grpc simple_switch_CLI; do
        rm -f "${PREFIX}/bin/${bin}"
    done

    # Remove bundled libraries
    rm -rf "${PREFIX}/lib/p4-bindist"

    # Remove share files
    rm -rf "${PREFIX}/share/p4c"

    # Remove linker config
    rm -f /etc/ld.so.conf.d/p4-bindist.conf
    ldconfig

    echo "Uninstall complete."
}

# Check for root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root (use sudo)."
    exit 1
fi

check_os

if [ "$UNINSTALL" -eq 1 ]; then
    do_uninstall
else
    install_runtime_deps
    do_install
fi
