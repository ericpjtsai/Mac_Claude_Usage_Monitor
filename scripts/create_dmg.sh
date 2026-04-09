#!/bin/bash
set -euo pipefail

APP_NAME="ClaudeUsageMonitor"
VERSION="1.0.3"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
DMG_NAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
STAGING_DIR="$DIST_DIR/dmg-staging"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found. Run ./scripts/build.sh first."
    exit 1
fi

echo "=== Creating DMG ==="

# Clean up
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy app to staging
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create Applications symlink for drag-to-install
ln -s /Applications "$STAGING_DIR/Applications"

# Create README
cat > "$STAGING_DIR/README.txt" << 'README'
Claude Usage Monitor - Installation Guide
==========================================

1. Drag "ClaudeUsageMonitor.app" to the Applications folder.

2. FIRST LAUNCH (important):
   Since this app is not from the App Store, macOS will block it.
   To open it:
   - Right-click (or Control-click) the app
   - Select "Open" from the context menu
   - Click "Open" in the dialog

   Alternatively:
   - Go to System Settings > Privacy & Security
   - Scroll down and click "Open Anyway"

   You only need to do this once.

3. The app will appear as a circular icon in your menu bar.
   Click it and sign in with your Claude account.

4. Your preferences and login will persist across updates.
   To update: just drag the new .app over the old one.
README

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "=== DMG created ==="
echo "Path: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
echo ""
echo "Share this file with friends!"
