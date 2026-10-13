#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
app="$PWD/build/Call Clock.app"
mkdir -p "$app/Contents/MacOS"
swiftc -O Sources/CallClock.swift -o "$app/Contents/MacOS/CallClock" -framework Cocoa
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>CallClock</string>
<key>CFBundleIdentifier</key><string>com.alejoacelas.call-clock</string>
<key>CFBundleName</key><string>Call Clock</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app"
echo "Built $app"
