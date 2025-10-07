#!/bin/bash

# ============================================================================
# Clean AppleDouble Files from Package Payload
# ============================================================================
# This script extracts a .pkg file, removes AppleDouble files from the
# payload, and rebuilds the package. This is necessary because pkgbuild
# creates these files when archiving from Dropbox folders.
# ============================================================================

set -e

PKG_FILE="$1"

if [ -z "$PKG_FILE" ] || [ ! -f "$PKG_FILE" ]; then
    echo "Usage: $0 <package-file.pkg>"
    exit 1
fi

echo "Cleaning AppleDouble files from: $PKG_FILE"

# Create temp directory
TEMP_DIR="/tmp/pkg_clean_$$"
mkdir -p "$TEMP_DIR"

# Expand package
echo "1. Expanding package..."
pkgutil --expand "$PKG_FILE" "$TEMP_DIR/expanded"

# Find component packages
for COMPONENT in "$TEMP_DIR/expanded"/*.pkg; do
    if [ -d "$COMPONENT" ] && [ -f "$COMPONENT/Payload" ]; then
        echo "2. Processing component: $(basename "$COMPONENT")"

        # Count AppleDouble files IN the tar
        BEFORE=$(tar -tzf "$COMPONENT/Payload" 2>/dev/null | grep -E '/\._|^\._' | wc -l | tr -d ' ')
        echo "   - Found $BEFORE AppleDouble files in tar archive"

        if [ "$BEFORE" -gt 0 ]; then
            # Extract payload WITHOUT AppleDouble files
            echo "   - Extracting and filtering payload..."
            mkdir -p "$TEMP_DIR/payload"
            cd "$TEMP_DIR/payload"

            # Extract excluding AppleDouble files
            tar -xzf "$COMPONENT/Payload" --exclude='._*' --exclude='__*'

            # Repack payload with COPYFILE_DISABLE
            echo "   - Repacking clean payload..."
            export COPYFILE_DISABLE=1
            tar -czf "$COMPONENT/Payload.new" .
            mv "$COMPONENT/Payload.new" "$COMPONENT/Payload"

            # Clean up
            cd "$TEMP_DIR"
            rm -rf payload

            # Verify
            AFTER=$(tar -tzf "$COMPONENT/Payload" 2>/dev/null | grep -E '/\._|^\._' | wc -l | tr -d ' ')
            echo "   - After cleaning: $AFTER AppleDouble files remain"
        else
            echo "   - No AppleDouble files found, skipping"
        fi

        # Clean up
        cd "$TEMP_DIR"
        rm -rf payload
    fi
done

# Flatten package back (to /tmp first to avoid Dropbox issues)
echo "3. Rebuilding package..."
TEMP_PKG="/tmp/cleaned_pkg_$$.pkg"
pkgutil --flatten "$TEMP_DIR/expanded" "$TEMP_PKG"

# Move to final location
CLEAN_PKG="${PKG_FILE%.pkg}-clean.pkg"
mv "$TEMP_PKG" "$CLEAN_PKG"

# Clean up
rm -rf "$TEMP_DIR"

echo "4. Done! Clean package: $CLEAN_PKG"
echo ""
echo "Verification:"
pkgutil --expand "$CLEAN_PKG" "$TEMP_DIR/verify"
for COMPONENT in "$TEMP_DIR/verify"/*.pkg; do
    if [ -f "$COMPONENT/Payload" ]; then
        COUNT=$(tar -tzf "$COMPONENT/Payload" 2>/dev/null | grep -E '/\._|^\._' | wc -l | tr -d ' ')
        echo "  - AppleDouble files in $(basename "$COMPONENT"): $COUNT"
    fi
done
rm -rf "$TEMP_DIR"

echo ""
echo "Replace original with clean version:"
echo "  mv \"$CLEAN_PKG\" \"$PKG_FILE\""
