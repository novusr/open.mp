#!/bin/bash
# =============================================================================
# build_deps_android.sh - Build dependencies for Android ARM64
# =============================================================================
# This script builds OpenSSL and SQLite3 for Android ARM64.
# Header-only libraries (nlohmann_json, ghc-filesystem, cxxopts) don't need building.
# =============================================================================
set -e

# Configuration
NDK_PATH="${ANDROID_NDK:-/home/novusr/Android/Sdk/ndk/29.0.14206865}"
API_LEVEL=21
TARGET=aarch64-linux-android
DEPS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/android-deps/arm64-v8a"
DOWNLOAD_DIR="/tmp/android-deps-src"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Android Dependencies Build Script ===${NC}"
echo "NDK: $NDK_PATH"
echo "API Level: $API_LEVEL"
echo "Output: $DEPS_DIR"

# Setup NDK toolchain paths
TOOLCHAIN="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
export CC="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang"
export CXX="$TOOLCHAIN/bin/${TARGET}${API_LEVEL}-clang++"
export AR="$TOOLCHAIN/bin/llvm-ar"
export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
export STRIP="$TOOLCHAIN/bin/llvm-strip"

# Required by OpenSSL's Configure script
export ANDROID_NDK_ROOT="$NDK_PATH"
export ANDROID_NDK_HOME="$NDK_PATH"
export PATH="$TOOLCHAIN/bin:$PATH"

# Verify toolchain
if [ ! -f "$CC" ]; then
    echo -e "${RED}Error: Clang not found at $CC${NC}"
    exit 1
fi

mkdir -p "$DEPS_DIR"/{lib,include}
mkdir -p "$DOWNLOAD_DIR"

# =============================================================================
# OpenSSL 1.1.1w (better Android compatibility - no getentropy dependency)
# =============================================================================
build_openssl() {
    echo -e "${YELLOW}Building OpenSSL 1.1.1w...${NC}"
    
    cd "$DOWNLOAD_DIR"
    
    if [ ! -d "openssl-1.1.1w" ]; then
        if [ ! -f "openssl-1.1.1w.tar.gz" ]; then
            wget -q https://www.openssl.org/source/openssl-1.1.1w.tar.gz
        fi
        tar -xzf openssl-1.1.1w.tar.gz
    fi
    
    cd openssl-1.1.1w
    
    # Clean previous build
    make clean 2>/dev/null || true
    
    # Configure for Android ARM64
    ./Configure android-arm64 \
        -D__ANDROID_API__=$API_LEVEL \
        --prefix="$DEPS_DIR" \
        no-shared \
        no-tests \
        no-ui-console
    
    make -j$(nproc)
    make install_sw
    
    echo -e "${GREEN}OpenSSL build complete${NC}"
}

# =============================================================================
# SQLite3 3.36.0
# =============================================================================
build_sqlite() {
    echo -e "${YELLOW}Building SQLite3 3.36.0...${NC}"
    
    cd "$DOWNLOAD_DIR"
    
    # Download amalgamation
    if [ ! -f "sqlite-amalgamation-3360000.zip" ]; then
        wget -q https://www.sqlite.org/2021/sqlite-amalgamation-3360000.zip
    fi
    
    if [ ! -d "sqlite-amalgamation-3360000" ]; then
        unzip -q sqlite-amalgamation-3360000.zip
    fi
    
    cd sqlite-amalgamation-3360000
    
    # Compile as static library
    $CC -c sqlite3.c -o sqlite3.o \
        -DSQLITE_ENABLE_FTS5 \
        -DSQLITE_ENABLE_JSON1 \
        -DSQLITE_THREADSAFE=2 \
        -O2
    
    $AR rcs "$DEPS_DIR/lib/libsqlite3.a" sqlite3.o
    cp sqlite3.h "$DEPS_DIR/include/"
    cp sqlite3ext.h "$DEPS_DIR/include/"
    
    echo -e "${GREEN}SQLite3 build complete${NC}"
}

# =============================================================================
# zlib 1.3.1
# =============================================================================
build_zlib() {
    echo -e "${YELLOW}Building zlib 1.3.1...${NC}"
    
    cd "$DOWNLOAD_DIR"
    
    if [ ! -d "zlib-1.3.1" ]; then
        if [ ! -f "zlib-1.3.1.tar.gz" ]; then
            wget -q https://zlib.net/zlib-1.3.1.tar.gz
        fi
        tar -xzf zlib-1.3.1.tar.gz
    fi
    
    cd zlib-1.3.1
    
    # Clean
    make clean 2>/dev/null || true
    
    # Configure
    CHOST=$TARGET ./configure \
        --prefix="$DEPS_DIR" \
        --static
    
    make -j$(nproc)
    make install
    
    echo -e "${GREEN}zlib build complete${NC}"
}

# =============================================================================
# Main
# =============================================================================
echo ""
echo "Select dependencies to build:"
echo "  1) All (OpenSSL, SQLite3, zlib)"
echo "  2) OpenSSL only"
echo "  3) SQLite3 only"
echo "  4) zlib only"
echo ""

read -p "Choice [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        build_zlib
        build_openssl
        build_sqlite
        ;;
    2)
        build_openssl
        ;;
    3)
        build_sqlite
        ;;
    4)
        build_zlib
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== Dependencies Build Complete ===${NC}"
echo "Libraries installed to: $DEPS_DIR"
ls -la "$DEPS_DIR/lib/"
