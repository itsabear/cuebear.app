#!/bin/bash

# Cue Bear Bridge Dependency Checker
# Tests all libraries, executables, and dependencies required for Bridge to run properly

set -e

echo "🔍 Cue Bear Bridge Dependency Checker"
echo "===================================="

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

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Function to check a dependency
check_dependency() {
    local name="$1"
    local path="$2"
    local description="$3"
    local critical="${4:-true}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -e "$path" ]; then
        if [ -f "$path" ]; then
            if [ -x "$path" ]; then
                print_success "$name: Found and executable"
                PASSED_CHECKS=$((PASSED_CHECKS + 1))
                
                # Check if it's a binary/library
                if file "$path" | grep -q "Mach-O"; then
                    print_status "  Type: $(file "$path" | cut -d: -f2)"
                    
                    # Check code signing
                    if codesign -dv "$path" 2>/dev/null; then
                        print_success "  Code signing: Valid"
                    else
                        print_warning "  Code signing: Not signed or invalid"
                        WARNING_CHECKS=$((WARNING_CHECKS + 1))
                    fi
                fi
            else
                print_error "$name: Found but not executable"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))
            fi
        else
            print_success "$name: Found (directory)"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        fi
    else
        if [ "$critical" = "true" ]; then
            print_error "$name: Not found"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        else
            print_warning "$name: Not found (optional)"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        fi
    fi
    
    if [ -n "$description" ]; then
        print_status "  Purpose: $description"
    fi
    echo ""
}

# Function to check system frameworks
check_framework() {
    local name="$1"
    local path="$2"
    local description="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    
    if [ -d "$path" ]; then
        print_success "$name: Framework found"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        
        # Check framework version
        if [ -f "$path/Resources/Info.plist" ]; then
            local version=$(plutil -p "$path/Resources/Info.plist" 2>/dev/null | grep -A1 "CFBundleShortVersionString" | tail -1 | cut -d'"' -f2)
            if [ -n "$version" ]; then
                print_status "  Version: $version"
            fi
        fi
        
        # Check if framework is loadable
        if otool -L "$path/$name" 2>/dev/null | grep -q "$name"; then
            print_success "  Framework is loadable"
        else
            print_warning "  Framework may not be loadable"
            WARNING_CHECKS=$((WARNING_CHECKS + 1))
        fi
    else
        print_error "$name: Framework not found"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
    
    if [ -n "$description" ]; then
        print_status "  Purpose: $description"
    fi
    echo ""
}

# Function to check library dependencies
check_library_deps() {
    local lib_path="$1"
    local lib_name="$2"
    
    if [ -f "$lib_path" ]; then
        print_status "Checking dependencies for $lib_name:"
        
        # Get library dependencies
        local deps=$(otool -L "$lib_path" 2>/dev/null | grep -v "$lib_path" | grep -v ":" | awk '{print $1}' | sort -u)
        
        if [ -n "$deps" ]; then
            while IFS= read -r dep; do
                if [ -n "$dep" ]; then
                    if [ -f "$dep" ]; then
                        print_success "  ✓ $dep"
                    else
                        print_error "  ✗ $dep (missing)"
                        FAILED_CHECKS=$((FAILED_CHECKS + 1))
                    fi
                fi
            done <<< "$deps"
        else
            print_status "  No external dependencies"
        fi
        echo ""
    fi
}

echo "🔍 Checking System Requirements..."
echo "================================="

# Check macOS version
print_status "Checking macOS version..."
MACOS_VERSION=$(sw_vers -productVersion)
MACOS_BUILD=$(sw_vers -buildVersion)
print_success "macOS Version: $MACOS_VERSION (Build $MACOS_BUILD)"

# Check architecture
ARCH=$(uname -m)
print_success "Architecture: $ARCH"
echo ""

echo "🔍 Checking Required System Frameworks..."
echo "========================================"

# Check essential macOS frameworks
check_framework "CoreMIDI" "/System/Library/Frameworks/CoreMIDI.framework" "MIDI communication"
check_framework "Network" "/System/Library/Frameworks/Network.framework" "Network communication"
check_framework "Foundation" "/System/Library/Frameworks/Foundation.framework" "Core system services"
check_framework "AppKit" "/System/Library/Frameworks/AppKit.framework" "macOS user interface"
check_framework "CoreServices" "/System/Library/Frameworks/CoreServices.framework" "System services"
check_framework "Security" "/System/Library/Frameworks/Security.framework" "Security services"

echo "🔍 Checking Cue Bear Bridge Resources..."
echo "======================================="

# Get Bridge source directory
BRIDGE_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
print_status "Bridge source directory: $BRIDGE_SOURCE"

# Check Bridge Resources directory
check_dependency "Bridge Resources" "$BRIDGE_SOURCE/Resources" "Bundled libraries and helpers"

# Check individual bundled libraries
if [ -d "$BRIDGE_SOURCE/Resources/Frameworks" ]; then
    echo "📚 Checking Bundled Libraries..."
    echo "================================"
    
    for lib in "$BRIDGE_SOURCE/Resources/Frameworks"/*.dylib; do
        if [ -f "$lib" ]; then
            lib_name=$(basename "$lib")
            check_dependency "$lib_name" "$lib" "Bundled library"
            check_library_deps "$lib" "$lib_name"
        fi
    done
fi

# Check iproxy executable
if [ -d "$BRIDGE_SOURCE/Resources/Helpers" ]; then
    echo "🔧 Checking Helper Executables..."
    echo "================================="
    
    for helper in "$BRIDGE_SOURCE/Resources/Helpers"/*; do
        if [ -f "$helper" ]; then
            helper_name=$(basename "$helper")
            check_dependency "$helper_name" "$helper" "Helper executable"
            
            # Special check for iproxy
            if [[ "$helper_name" == *"iproxy"* ]]; then
                print_status "  Testing iproxy functionality..."
                if "$helper" --help 2>/dev/null | grep -q "iproxy"; then
                    print_success "  iproxy responds to --help"
                else
                    print_warning "  iproxy may not be functional"
                    WARNING_CHECKS=$((WARNING_CHECKS + 1))
                fi
            fi
        fi
    done
fi

echo "🔍 Checking System Libraries..."
echo "==============================="

# Check common system libraries that Bridge might use
check_dependency "libSystem" "/usr/lib/libSystem.B.dylib" "Core system library"
check_dependency "libc++" "/usr/lib/libc++.1.dylib" "C++ standard library"
check_dependency "libobjc" "/usr/lib/libobjc.A.dylib" "Objective-C runtime"

# Check for libimobiledevice related libraries
check_dependency "libimobiledevice" "/usr/local/lib/libimobiledevice.dylib" "iOS device communication" "false"
check_dependency "libusbmuxd" "/usr/local/lib/libusbmuxd.dylib" "USB multiplexing" "false"
check_dependency "libplist" "/usr/local/lib/libplist.dylib" "Property list handling" "false"

echo "🔍 Checking Development Tools..."
echo "==============================="

# Check Xcode command line tools
check_dependency "xcodebuild" "/usr/bin/xcodebuild" "Xcode build system" "false"
check_dependency "otool" "/usr/bin/otool" "Object file analysis tool"
check_dependency "codesign" "/usr/bin/codesign" "Code signing tool"
check_dependency "plutil" "/usr/bin/plutil" "Property list utility"

echo "🔍 Checking Network Services..."
echo "==============================="

# Check Bonjour/mDNSResponder
check_dependency "mDNSResponder" "/usr/sbin/mDNSResponder" "Bonjour service discovery" "false"

# Check if we can resolve local hostname
if hostname -f >/dev/null 2>&1; then
    print_success "Hostname resolution: Working"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_warning "Hostname resolution: May have issues"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

echo "🔍 Checking USB Device Support..."
echo "================================="

# Check if we can list USB devices
if system_profiler SPUSBDataType >/dev/null 2>&1; then
    print_success "USB device enumeration: Working"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_warning "USB device enumeration: May have issues"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

# Check for iOS device support
if [ -d "/System/Library/PrivateFrameworks/MobileDevice.framework" ]; then
    print_success "iOS device support: Available"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    print_warning "iOS device support: Not available (may need Xcode)"
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

echo "🔍 Checking MIDI System..."
echo "=========================="

# Check if MIDI system is working
if [ -d "/System/Library/Frameworks/CoreMIDI.framework" ]; then
    print_success "CoreMIDI framework: Available"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    
    # Try to get MIDI device count (this might fail if no MIDI devices)
    if command -v system_profiler >/dev/null 2>&1; then
        midi_devices=$(system_profiler SPMIDIDataType 2>/dev/null | grep -c "Device" || echo "0")
        print_status "MIDI devices detected: $midi_devices"
    fi
else
    print_error "CoreMIDI framework: Not available"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
fi
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

echo "📊 Dependency Check Summary"
echo "=========================="
echo "Total checks: $TOTAL_CHECKS"
print_success "Passed: $PASSED_CHECKS"
if [ $WARNING_CHECKS -gt 0 ]; then
    print_warning "Warnings: $WARNING_CHECKS"
fi
if [ $FAILED_CHECKS -gt 0 ]; then
    print_error "Failed: $FAILED_CHECKS"
fi

echo ""
if [ $FAILED_CHECKS -eq 0 ]; then
    if [ $WARNING_CHECKS -eq 0 ]; then
        print_success "🎉 All dependencies are properly installed!"
        print_success "Cue Bear Bridge should run without issues."
    else
        print_warning "⚠️  Most dependencies are OK, but there are some warnings."
        print_status "Cue Bear Bridge should work, but some features may be limited."
    fi
else
    print_error "❌ Some critical dependencies are missing or broken."
    print_error "Cue Bear Bridge may not work properly."
    echo ""
    print_status "To fix missing dependencies:"
    echo "1. Install Xcode from the App Store"
    echo "2. Install Xcode command line tools: xcode-select --install"
    echo "3. Install libimobiledevice: brew install libimobiledevice"
    echo "4. Rebuild the Bridge app in Xcode"
fi

echo ""
print_status "For detailed information about any specific dependency,"
print_status "check the individual test results above."
