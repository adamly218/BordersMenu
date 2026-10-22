#!/bin/bash
# Builds BordersMenu.app and installs it to /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/BordersMenu.app"

rm -rf "$ROOT/dist"
mkdir -p "$APP/Contents/MacOS"

swiftc -O "$ROOT/main.swift" -o "$APP/Contents/MacOS/BordersMenu" \
    -framework AppKit -framework ServiceManagement

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>BordersMenu</string>
    <key>CFBundleDisplayName</key><string>Borders Menu</string>
    <key>CFBundleIdentifier</key><string>io.github.adamly218.bordersmenu</string>
    <key>CFBundleExecutable</key><string>BordersMenu</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"

pkill -x BordersMenu 2>/dev/null || true
rm -rf /Applications/BordersMenu.app
ditto "$APP" /Applications/BordersMenu.app
open /Applications/BordersMenu.app
echo "Installed /Applications/BordersMenu.app"
