#!/bin/bash
# Builds Floaty.app from Floaty.swift.
# Needs Apple's Command Line Tools:  xcode-select --install
set -euo pipefail
cd "$(dirname "$0")"

APP="Floaty"

echo "Compiling…"
swiftc -parse-as-library -O "$APP.swift" -o "$APP"

# App icon (drawn by make_icon.swift; delete AppIcon.icns to redraw it).
if [ ! -f AppIcon.icns ]; then
  echo "Drawing icon…"
  swift make_icon.swift
fi

echo "Packaging $APP.app…"
rm -rf "$APP.app"
mkdir -p "$APP.app/Contents/MacOS" "$APP.app/Contents/Resources"
mv "$APP" "$APP.app/Contents/MacOS/"
cp AppIcon.icns "$APP.app/Contents/Resources/"

cat > "$APP.app/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$APP</string>
  <key>CFBundleDisplayName</key><string>$APP</string>
  <key>CFBundleIdentifier</key><string>com.example.floaty</string>
  <key>CFBundleExecutable</key><string>$APP</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Ad-hoc signature so it runs on your own Mac.
codesign --force --sign - "$APP.app"

echo "Done. Launch with:  open $APP.app"
