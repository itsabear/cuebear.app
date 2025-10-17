#!/bin/bash
set -e

echo "🔨 Building Universal libusbmuxd Libraries"
echo "=========================================="

FRAMEWORKS_DIR="$(dirname "$0")/Frameworks"
BUILD_DIR="/tmp/cuebear_universal_build"
mkdir -p "$FRAMEWORKS_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$BUILD_DIR"

# Define versions
LIBPLIST_VERSION="2.7.0"
GLUE_VERSION="1.3.2"
LIBUSBMUXD_VERSION="2.1.1"

echo ""
echo "📦 Step 1: Download source archives..."
curl -L "https://github.com/libimobiledevice/libplist/archive/refs/tags/${LIBPLIST_VERSION}.tar.gz" -o libplist.tar.gz
curl -L "https://github.com/libimobiledevice/libimobiledevice-glue/archive/refs/tags/${GLUE_VERSION}.tar.gz" -o glue.tar.gz
curl -L "https://github.com/libimobiledevice/libusbmuxd/archive/refs/tags/${LIBUSBMUXD_VERSION}.tar.gz" -o libusbmuxd.tar.gz

echo ""
echo "📂 Step 2: Extract archives..."
tar xzf libplist.tar.gz
tar xzf glue.tar.gz
tar xzf libusbmuxd.tar.gz

# Function to build a library for both architectures
build_library() {
    local name=$1
    local src_dir=$2
    local version=$3
    local dylib_name=$4

    echo ""
    echo "========================================"
    echo "Building $name for x86_64..."
    echo "========================================"
    cd "$src_dir"

    # Create version file
    echo "$version" > .tarball-version

    # Clean completely
    rm -rf build-x86_64
    mkdir build-x86_64
    cd build-x86_64

    # Configure for x86_64 with proper CC/CXX environment
    PKG_CONFIG_PATH="$BUILD_DIR/install-x86_64/lib/pkgconfig" \
    ../autogen.sh --prefix="$BUILD_DIR/install-x86_64" \
        --host=x86_64-apple-darwin \
        --disable-dependency-tracking \
        --without-cython \
        CC="clang -arch x86_64" \
        CXX="clang++ -arch x86_64" \
        CFLAGS="-arch x86_64 -mmacosx-version-min=10.13" \
        CXXFLAGS="-arch x86_64 -mmacosx-version-min=10.13" \
        LDFLAGS="-arch x86_64"

    # Build only libraries, not tests
    PKG_CONFIG_PATH="$BUILD_DIR/install-x86_64/lib/pkgconfig" \
    make -j$(sysctl -n hw.ncpu) install-strip

    echo ""
    echo "========================================"
    echo "Building $name for arm64..."
    echo "========================================"
    cd "$src_dir"

    # Clean completely
    rm -rf build-arm64
    mkdir build-arm64
    cd build-arm64

    # Configure for arm64
    PKG_CONFIG_PATH="$BUILD_DIR/install-arm64/lib/pkgconfig" \
    ../autogen.sh --prefix="$BUILD_DIR/install-arm64" \
        --host=arm-apple-darwin \
        --disable-dependency-tracking \
        --without-cython \
        CC="clang -arch arm64" \
        CXX="clang++ -arch arm64" \
        CFLAGS="-arch arm64 -mmacosx-version-min=11.0" \
        CXXFLAGS="-arch arm64 -mmacosx-version-min=11.0" \
        LDFLAGS="-arch arm64"

    # Build only libraries, not tests
    PKG_CONFIG_PATH="$BUILD_DIR/install-arm64/lib/pkgconfig" \
    make -j$(sysctl -n hw.ncpu) install-strip

    cd "$BUILD_DIR"
}

# Build each library
echo ""
echo "========================================"
echo "Building libplist..."
echo "========================================"
build_library "libplist" "$BUILD_DIR/libplist-${LIBPLIST_VERSION}" "${LIBPLIST_VERSION}" "libplist-2.0.dylib"

echo ""
echo "========================================"
echo "Building libimobiledevice-glue..."
echo "========================================"
build_library "libimobiledevice-glue" "$BUILD_DIR/libimobiledevice-glue-${GLUE_VERSION}" "${GLUE_VERSION}" "libimobiledevice-glue-1.0.dylib"

echo ""
echo "========================================"
echo "Building libusbmuxd..."
echo "========================================"
build_library "libusbmuxd" "$BUILD_DIR/libusbmuxd-${LIBUSBMUXD_VERSION}" "${LIBUSBMUXD_VERSION}" "libusbmuxd-2.0.dylib"

echo ""
echo "🔗 Step 3: Creating universal fat binaries..."

# Create universal binaries
create_universal() {
    local lib_pattern=$1
    local output_name=$2
    echo "  Creating universal $output_name..."

    # Find the actual library file (might have version numbers)
    local x86_lib=$(find "$BUILD_DIR/install-x86_64/lib/" -name "$lib_pattern*" -type f | head -1)
    local arm_lib=$(find "$BUILD_DIR/install-arm64/lib/" -name "$lib_pattern*" -type f | head -1)

    if [ -z "$x86_lib" ] || [ -z "$arm_lib" ]; then
        echo "    ⚠️  Warning: Could not find both architectures for $lib_pattern"
        return
    fi

    lipo -create "$x86_lib" "$arm_lib" -output "$FRAMEWORKS_DIR/$output_name"

    # Fix install names to use @rpath
    install_name_tool -id "@rpath/$output_name" "$FRAMEWORKS_DIR/$output_name"
}

create_universal "libplist-2.0" "libplist-2.0.dylib"
create_universal "libimobiledevice-glue-1.0" "libimobiledevice-glue-1.0.dylib"
create_universal "libusbmuxd-2.0" "libusbmuxd-2.0.dylib"

# Fix dependencies between libraries
echo ""
echo "🔧 Step 4: Fixing library dependencies..."
install_name_tool -change "/tmp/cuebear_universal_build/install-arm64/lib/libplist-2.0.dylib" "@rpath/libplist-2.0.dylib" "$FRAMEWORKS_DIR/libimobiledevice-glue-1.0.dylib" 2>/dev/null || true
install_name_tool -change "/tmp/cuebear_universal_build/install-x86_64/lib/libplist-2.0.dylib" "@rpath/libplist-2.0.dylib" "$FRAMEWORKS_DIR/libimobiledevice-glue-1.0.dylib" 2>/dev/null || true

install_name_tool -change "/tmp/cuebear_universal_build/install-arm64/lib/libplist-2.0.dylib" "@rpath/libplist-2.0.dylib" "$FRAMEWORKS_DIR/libusbmuxd-2.0.dylib" 2>/dev/null || true
install_name_tool -change "/tmp/cuebear_universal_build/install-x86_64/lib/libplist-2.0.dylib" "@rpath/libplist-2.0.dylib" "$FRAMEWORKS_DIR/libusbmuxd-2.0.dylib" 2>/dev/null || true

install_name_tool -change "/tmp/cuebear_universal_build/install-arm64/lib/libimobiledevice-glue-1.0.dylib" "@rpath/libimobiledevice-glue-1.0.dylib" "$FRAMEWORKS_DIR/libusbmuxd-2.0.dylib" 2>/dev/null || true
install_name_tool -change "/tmp/cuebear_universal_build/install-x86_64/lib/libimobiledevice-glue-1.0.dylib" "@rpath/libimobiledevice-glue-1.0.dylib" "$FRAMEWORKS_DIR/libusbmuxd-2.0.dylib" 2>/dev/null || true

echo ""
echo "✅ Step 5: Verify universal binaries..."
for lib in "$FRAMEWORKS_DIR"/*.dylib; do
    echo "  $(basename "$lib"):"
    lipo -info "$lib" | sed 's/^/    /'
    echo "    Install name: $(otool -D "$lib" | tail -1)"
done

echo ""
echo "🎉 SUCCESS! Universal libraries created in:"
echo "   $FRAMEWORKS_DIR"
echo ""
echo "Next step: Build the app with xcodebuild"

