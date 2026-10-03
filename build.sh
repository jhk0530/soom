#!/bin/zsh
set -eu
cd "$(dirname "$0")"
SOOM_OUTPUT="${1:-$PWD/build}"
mkdir -p "$SOOM_OUTPUT/soom.app/Contents/MacOS" "$SOOM_OUTPUT/soom.app/Contents/Resources"
SOOM_APP="$SOOM_OUTPUT/soom.app"
xcrun swiftc -parse-as-library soomsoom/sooomApp.swift \
    -module-cache-path "${TMPDIR:-/tmp}/soom-module-cache" \
    -default-isolation MainActor -target arm64-apple-macos26.2 -O \
    -framework SwiftUI -framework AppKit -o "$SOOM_APP/Contents/MacOS/soom"
cp soomsoom/AppIcon.icns "$SOOM_APP/Contents/Resources/AppIcon.icns"
cp -R soomsoom/StatusIcons "$SOOM_APP/Contents/Resources/"
cat > "$SOOM_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>soom</string>
<key>CFBundleIdentifier</key><string>jhk0530.soomsoom</string>
<key>CFBundleName</key><string>soom</string>
<key>CFBundleDisplayName</key><string>soom</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundleShortVersionString</key><string>0.4</string>
<key>LSMinimumSystemVersion</key><string>26.2</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$SOOM_APP"
codesign --verify --strict "$SOOM_APP"
printf '%s\n' "$SOOM_APP"
