# Custom Color Picker

A custom macOS NSColorPanel plugin that replaces the legacy color picker with a modern interface.

## Features
- **Color Wheel** — Color wheel with click-drag selection
- **Brightness Slider** — Vertical brightness slider alongside the wheel
- **Hex Input** — Type hex codes directly, copy/paste support

## Build & Install

```bash
chmod +x build.sh
./build.sh
```

This compiles the plugin and installs it to `~/Library/ColorPickers/`.

Restart any running app to see the new tab in its color panel.

## Uninstall

```bash
rm -rf ~/Library/ColorPickers/ColorPickerFixer.colorPicker
```

## Requirements
- macOS 14.0+
- Xcode Command Line Tools (`xcode-select --install`)

## How It Works
macOS loads `.colorPicker` bundles from `~/Library/ColorPickers/` automatically. The plugin's principal class conforms to `NSColorPickingCustom`, which integrates it as a new tab in every app's `NSColorPanel`. No injection, no SIP concerns.
