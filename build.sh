#!/bin/bash
# Builds BordersMenu.app and installs it to /Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/dist/BordersMenu.app"

rm -rf "$ROOT/dist"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O "$ROOT/main.swift" -o "$APP/Contents/MacOS/BordersMenu" \
    -framework AppKit -framework ServiceManagement

# App icon from icon/icon.png (redraw it with: swift icon/make-icon.swift icon/icon.png).
ICONSET="$ROOT/dist/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ROOT/icon/icon.png" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null
    sips -z $((size * 2)) $((size * 2)) "$ROOT/icon/icon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>BordersMenu</string>
    <key>CFBundleDisplayName</key><string>Borders Menu</string>
    <key>CFBundleIdentifier</key><string>io.github.adamly218.bordersmenu</string>
    <key>CFBundleExecutable</key><string>BordersMenu</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
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
