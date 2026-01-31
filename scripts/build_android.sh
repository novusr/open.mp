#!/bin/bash
# =============================================================================
# build_android.sh - Cross-compile open.mp server for Android ARM64
# =============================================================================
set -e

# Configuration
NDK_PATH="${ANDROID_NDK:-/home/novusr/Android/Sdk/ndk/29.0.14206865}"
BUILD_DIR="build-android-arm64"
CONFIG="${CONFIG:-RelWithDebInfo}"
ANDROID_ABI="${ANDROID_ABI:-arm64-v8a}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-21}"
ANDROID_STL="${ANDROID_STL:-c++_static}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== open.mp Android ARM64 Build Script ===${NC}"
echo "NDK Path: $NDK_PATH"
echo "Build Type: $CONFIG"
echo "Android ABI: $ANDROID_ABI"
echo "Android Platform: $ANDROID_PLATFORM"

# Verify NDK exists
if [ ! -d "$NDK_PATH" ]; then
    echo -e "${RED}Error: NDK not found at $NDK_PATH${NC}"
    echo "Set ANDROID_NDK environment variable or edit this script."
    exit 1
fi

TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake"
if [ ! -f "$TOOLCHAIN_FILE" ]; then
    echo -e "${RED}Error: NDK toolchain file not found at $TOOLCHAIN_FILE${NC}"
    exit 1
fi

# Navigate to project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "${YELLOW}Project root: $PROJECT_ROOT${NC}"

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo -e "${GREEN}Configuring CMake...${NC}"

# Configure with NDK toolchain
cmake .. \
    -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DANDROID_ABI="$ANDROID_ABI" \
    -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DANDROID_STL="$ANDROID_STL" \
    -DCMAKE_BUILD_TYPE="$CONFIG" \
    -DBUILD_SERVER=ON \
    -DBUILD_PAWN_COMPONENT=ON \
    -DBUILD_LEGACY_COMPONENTS=ON \
    -DBUILD_SQLITE_COMPONENT=OFF \
    -DBUILD_UNICODE_COMPONENT=OFF \
    -DBUILD_TEST_COMPONENTS=OFF \
    -DBUILD_FIXES_COMPONENT=OFF \
    -DBUILD_ABI_CHECK_TOOL=OFF \
    -DSHARED_OPENSSL=OFF

echo -e "${GREEN}Building...${NC}"

# Build
cmake --build . --parallel $(nproc)

echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo "Output directory: $PROJECT_ROOT/$BUILD_DIR/Output/$CONFIG/Server/"
echo ""
echo "To deploy to Android device:"
echo "  adb push $BUILD_DIR/Output/$CONFIG/Server/ /data/local/tmp/omp/"
