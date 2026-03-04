#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE_NAME="ColorPickerFixer"
BUILD_DIR="$SCRIPT_DIR/build"
BUNDLE_DIR="$BUILD_DIR/$BUNDLE_NAME.colorPicker"
INSTALL_DIR="$HOME/Library/ColorPickers"

ask_user() {
    local message="${1:-Proceed?}"
    local default="${2:-y}"
    local prompt="(y/n)"
    
    if [ "$default" = "y" ]; then
        prompt="(Y/n)"
    elif [ "$default" = "n" ]; then
        prompt="(y/N)"
    fi
    
    while true; do
        echo ""
        read -p " > $message $prompt: " yn
        
        # Use default if empty input
        if [ -z "$yn" ]; then
            yn="$default"
        fi
        
        case $yn in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Invalid response. Please answer yes or no.";;
        esac
    done
}

echo "=== Building Color Picker ==="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$BUNDLE_DIR/Contents/"

# Compile
echo "Compiling..."
SDK_PATH=$(xcrun --show-sdk-path)

# Step 1: Compile to object file
swiftc \
    -module-name ColorPickerFixer \
    -parse-as-library \
    -c \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK_PATH" \
    -o "$BUILD_DIR/ColorPickerFixer.o" \
    "$SCRIPT_DIR/Sources/ColorPickerFixer.swift"

# Step 2: Link as a loadable bundle (MH_BUNDLE)
swiftc \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK_PATH" \
    -Xlinker -bundle \
    -o "$BUNDLE_DIR/Contents/MacOS/$BUNDLE_NAME" \
    "$BUILD_DIR/ColorPickerFixer.o"

echo "Bundle created at: $BUNDLE_DIR"

# Install
echo ""
echo "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"

# Check if bundle already exists and prompt to remove
if [ -d "$INSTALL_DIR/$BUNDLE_NAME.colorPicker" ]; then
    if ! ask_user "Color picker already installed. Remove existing version?"; then
        echo "Installation cancelled."
        exit 1
    fi
    rm -rf "$INSTALL_DIR/$BUNDLE_NAME.colorPicker"
fi

cp -R "$BUNDLE_DIR" "$INSTALL_DIR/"

if ask_user "Clean up build files?"; then
    rm -rf "$BUILD_DIR"
else
    echo "Keeping build files, stored at $BUILD_DIR"
fi

echo ""
echo "=== Done! ==="
echo "Color Picker Fixer installed to ~/Library/ColorPickers/"
echo ""
echo "You may need to restart the target app for it to show up."
echo ""
echo "To uninstall:"
echo "  rm -rf ~/Library/ColorPickers/$BUNDLE_NAME.colorPicker"
