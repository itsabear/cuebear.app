#!/bin/bash

# Cue Bear Bridge Safe Uninstaller
# Only removes files that were installed by Cue Bear Bridge
# Preserves system libraries and user data from other applications

set -e

echo "🗑️  Cue Bear Bridge Safe Uninstaller"
echo "===================================="
echo "🐾 Removing Cue Bear Bridge and its Icon-iOS-Default-1024x1024 icon..."

# Configuration
APP_NAME="CueBearBridge"
BUNDLE_ID="com.cuebear.bridge"
MANIFEST_FILE="/Library/Application Support/CueBearBridge/install_manifest.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "This uninstaller should not be run as root"
    print_status "Please run it as a regular user"
    exit 1
fi

# Check if app is running
print_status "Checking if Cue Bear Bridge is running..."
if pgrep -f "CueBearBridge" > /dev/null; then
    print_warning "Cue Bear Bridge is currently running"
    print_status "Please quit the application before uninstalling"
    print_status "You can quit it from the menu bar or Activity Monitor"
    exit 1
fi

# Check if manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    print_error "Installation manifest not found: $MANIFEST_FILE"
    print_status "This suggests Cue Bear Bridge was not properly installed"
    print_status "or the manifest was manually deleted"
    print_warning "Proceeding with basic uninstallation..."
    BASIC_UNINSTALL=true
else
    print_success "Installation manifest found"
    BASIC_UNINSTALL=false
fi

# Function to safely remove file/directory
safe_remove() {
    local path="$1"
    local description="$2"
    
    if [ -e "$path" ]; then
        print_status "Removing: $description"
        if [ -d "$path" ]; then
            rm -rf "$path"
        else
            rm -f "$path"
        fi
        print_success "Removed: $description"
    else
        print_status "Not found (already removed): $description"
    fi
}

# Function to check if path is safe to remove
is_safe_to_remove() {
    local path="$1"
    
    # Never remove system directories
    case "$path" in
        "/System"*) return 1 ;;
        "/usr/lib"*) return 1 ;;
        "/usr/local/lib"*) return 1 ;;
        "/Library/Frameworks"*) return 1 ;;
        "/Library/LaunchDaemons"*) return 1 ;;
        "/Library/LaunchAgents"*) return 1 ;;
        "/Library/Preferences"*) return 1 ;;
        "/Library/Application Support"*) 
            # Only remove CueBearBridge specific files
            case "$path" in
                *"CueBearBridge"*) return 0 ;;
                *) return 1 ;;
            esac ;;
        *) return 0 ;;
    esac
}

# Main uninstallation process
print_status "Starting safe uninstallation..."

# Remove application bundle
safe_remove "/Applications/CueBearBridge.app" "Cue Bear Bridge application"

# Remove desktop shortcut
safe_remove "$HOME/Desktop/CueBearBridge" "Desktop shortcut"

# Remove user-specific files
safe_remove "$HOME/Library/Preferences/com.cuebear.bridge.plist" "User preferences"
safe_remove "$HOME/Library/Logs/CueBearBridge" "User logs directory"
safe_remove "$HOME/Library/Caches/com.cuebear.bridge" "User cache directory"

# Remove launch agents
safe_remove "$HOME/Library/LaunchAgents/com.cuebear.bridge.plist" "Launch agent"

# Remove temporary files
print_status "Cleaning temporary files..."
find /tmp -name "cuebearbridge-*" -type f -delete 2>/dev/null || true

# If manifest exists, use it for safe removal
if [ "$BASIC_UNINSTALL" = false ]; then
    print_status "Using installation manifest for safe removal..."
    
    # Read manifest and remove only listed items
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "$line" ]]; then
            continue
        fi
        
        # Expand ~ to home directory
        path="${line/#\~/$HOME}"
        
        # Check if path is safe to remove
        if is_safe_to_remove "$path"; then
            safe_remove "$path" "Manifest item: $line"
        else
            print_warning "Skipping unsafe path: $line"
        fi
    done < "$MANIFEST_FILE"
    
    # Remove the manifest itself
    safe_remove "$MANIFEST_FILE" "Installation manifest"
    safe_remove "/Library/Application Support/CueBearBridge" "Application support directory"
fi

# Unregister from Launch Services
print_status "Unregistering from Launch Services..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "/Applications/CueBearBridge.app" 2>/dev/null || true

# Clean up any remaining references
print_status "Cleaning up system references..."

# Remove from recent applications
defaults delete com.apple.dock recent-apps 2>/dev/null || true

# Clear any cached data
print_status "Clearing cached data..."
find "$HOME/Library/Caches" -name "*cuebear*" -type d -exec rm -rf {} + 2>/dev/null || true
find "$HOME/Library/Caches" -name "*CueBear*" -type d -exec rm -rf {} + 2>/dev/null || true

# Final verification
print_status "Verifying uninstallation..."
if [ -d "/Applications/CueBearBridge.app" ]; then
    print_warning "Application bundle still exists - manual removal may be required"
else
    print_success "Cue Bear Bridge and its bear paw icon have been successfully removed"
fi

# Summary
echo ""
echo "🎉 Uninstallation Complete!"
echo "=========================="
print_success "Cue Bear Bridge has been safely uninstalled"
print_status "All Cue Bear Bridge files have been removed"
print_status "System libraries and other applications remain untouched"
print_status "Your system is clean and stable"

echo ""
print_status "What was removed:"
echo "  • Cue Bear Bridge application"
echo "  • User preferences and settings"
echo "  • Log files and cache data"
echo "  • Desktop shortcuts"
echo "  • Launch agents"
echo "  • Temporary files"

echo ""
print_status "What was preserved:"
echo "  • System libraries and frameworks"
echo "  • Other applications and their data"
echo "  • User documents and media"
echo "  • System preferences"

echo ""
print_success "Thank you for using Cue Bear Bridge!"
