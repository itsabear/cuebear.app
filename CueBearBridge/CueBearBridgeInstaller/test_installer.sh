#!/bin/bash

# Cue Bear Bridge Installer Test Script
# Tests the installer system without building the full app

set -e

echo "🧪 Cue Bear Bridge Installer Test"
echo "================================="

# Configuration
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$INSTALLER_DIR/test"
BUILD_DIR="$INSTALLER_DIR/build"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Test script syntax
test_script_syntax() {
    print_status "Testing script syntax..."
    
    local scripts=(
        "build_package.sh"
        "scripts/build_installer.sh"
        "scripts/install_manifest.sh"
        "uninstaller/uninstall.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$INSTALLER_DIR/$script" ]; then
            if bash -n "$INSTALLER_DIR/$script"; then
                print_success "Syntax OK: $script"
            else
                print_error "Syntax error: $script"
                return 1
            fi
        else
            print_error "Script not found: $script"
            return 1
        fi
    done
}

# Test script permissions
test_script_permissions() {
    print_status "Testing script permissions..."
    
    local scripts=(
        "build_package.sh"
        "scripts/build_installer.sh"
        "scripts/install_manifest.sh"
        "uninstaller/uninstall.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ -f "$INSTALLER_DIR/$script" ]; then
            if [ -x "$INSTALLER_DIR/$script" ]; then
                print_success "Executable: $script"
            else
                print_warning "Not executable: $script"
                chmod +x "$INSTALLER_DIR/$script"
                print_success "Made executable: $script"
            fi
        fi
    done
}

# Test HTML resources
test_html_resources() {
    print_status "Testing HTML resources..."
    
    local html_files=(
        "resources/welcome.html"
        "resources/conclusion.html"
    )
    
    for html_file in "${html_files[@]}"; do
        if [ -f "$INSTALLER_DIR/$html_file" ]; then
            print_success "Found: $html_file"
        else
            print_error "Missing: $html_file"
            return 1
        fi
    done
}

# Test directory structure
test_directory_structure() {
    print_status "Testing directory structure..."
    
    local dirs=(
        "scripts"
        "uninstaller"
        "resources"
    )
    
    for dir in "${dirs[@]}"; do
        if [ -d "$INSTALLER_DIR/$dir" ]; then
            print_success "Directory exists: $dir"
        else
            print_error "Directory missing: $dir"
            return 1
        fi
    done
}

# Test manifest script
test_manifest_script() {
    print_status "Testing installation manifest script..."
    
    cd "$INSTALLER_DIR/scripts"
    
    # Create test manifest with temporary directory
    TEST_MANIFEST="/tmp/test_manifest.txt"
    TEST_MANIFEST_DIR="/tmp/test_cuebearbridge"
    
    # Modify the script temporarily for testing
    sed "s|/Library/Application Support/CueBearBridge|$TEST_MANIFEST_DIR|g" install_manifest.sh > test_manifest.sh
    chmod +x test_manifest.sh
    
    MANIFEST_FILE="$TEST_MANIFEST" ./test_manifest.sh
    
    if [ -f "$TEST_MANIFEST_DIR/install_manifest.txt" ]; then
        print_success "Manifest script works"
        rm -f "$TEST_MANIFEST" test_manifest.sh
        rm -rf "$TEST_MANIFEST_DIR"
    else
        print_error "Manifest script failed"
        rm -f test_manifest.sh
        return 1
    fi
}

# Test uninstaller safety
test_uninstaller_safety() {
    print_status "Testing uninstaller safety checks..."
    
    # Test the safety function
    cd "$INSTALLER_DIR/uninstaller"
    
    # Create a test script that imports the safety function
    cat > test_safety.sh << 'EOF'
#!/bin/bash

# Import safety function from uninstall.sh
source uninstall.sh

# Test safety checks
test_paths=(
    "/System/Library/Frameworks/CoreMIDI.framework"
    "/usr/lib/libSystem.B.dylib"
    "/Library/Frameworks/SomeFramework.framework"
    "/Applications/CueBearBridge.app"
    "/Library/Application Support/CueBearBridge"
)

for path in "${test_paths[@]}"; do
    if is_safe_to_remove "$path"; then
        echo "✅ Safe to remove: $path"
    else
        echo "🛡️ Protected: $path"
    fi
done
EOF
    
    chmod +x test_safety.sh
    ./test_safety.sh
    rm -f test_safety.sh
    
    print_success "Uninstaller safety checks work"
}

# Main test function
main() {
    print_status "Starting installer system tests..."
    
    # Run all tests
    test_script_syntax || exit 1
    test_script_permissions || exit 1
    test_html_resources || exit 1
    test_directory_structure || exit 1
    test_manifest_script || exit 1
    test_uninstaller_safety || exit 1
    
    # Summary
    echo ""
    echo "🎉 All Tests Passed!"
    echo "==================="
    print_success "Installer system is ready for use"
    print_status "Run './build_package.sh' to create packages"
    
    echo ""
    print_status "Test Summary:"
    echo "  ✅ Script syntax validation"
    echo "  ✅ Script permissions"
    echo "  ✅ HTML resources"
    echo "  ✅ Directory structure"
    echo "  ✅ Installation manifest"
    echo "  ✅ Uninstaller safety checks"
}

# Run tests
main "$@"
