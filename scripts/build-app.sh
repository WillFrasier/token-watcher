#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Token Watcher"
BUNDLE_NAME="TokenWatcher.app"
BUILD_DIR="$PROJECT_DIR/.build/release"
OUTPUT_DIR="$PROJECT_DIR/dist"

echo "Building TokenWatcher..."
cd "$PROJECT_DIR"
swift build -c release 2>&1

echo "Packaging as .app bundle..."
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$OUTPUT_DIR/$BUNDLE_NAME/Contents/Resources"

cp "$BUILD_DIR/TokenWatcher" "$OUTPUT_DIR/$BUNDLE_NAME/Contents/MacOS/"
cp "$PROJECT_DIR/Info.plist" "$OUTPUT_DIR/$BUNDLE_NAME/Contents/"

# Generate a simple icon using SF Symbols via sips if available
if command -v iconutil &>/dev/null; then
    ICONSET_DIR="$OUTPUT_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    # Create a placeholder — replace with real icon assets for production
    for size in 16 32 64 128 256 512; do
        sips -s format png "$PROJECT_DIR/scripts/icon.png" \
             --resampleHeightWidth $size $size \
             --out "$ICONSET_DIR/icon_${size}x${size}.png" 2>/dev/null || true
        double=$((size * 2))
        sips -s format png "$PROJECT_DIR/scripts/icon.png" \
             --resampleHeightWidth $double $double \
             --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" 2>/dev/null || true
    done
    if ls "$ICONSET_DIR"/*.png &>/dev/null 2>&1; then
        iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/$BUNDLE_NAME/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    fi
    rm -rf "$ICONSET_DIR"
fi

echo ""
echo "Done: $OUTPUT_DIR/$BUNDLE_NAME"
echo ""
echo "To run: open \"$OUTPUT_DIR/$BUNDLE_NAME\""
echo "To install: cp -r \"$OUTPUT_DIR/$BUNDLE_NAME\" /Applications/"
