#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --product VideoTag
BIN="$(swift build -c release --show-bin-path)/VideoTag"
APP="$HOME/Applications/Video Tag.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/VideoTag"
cp vendor/planche-contact.sh "$APP/Contents/Resources/planche-contact.sh"
cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Video Tag</string>
<key>CFBundleDisplayName</key><string>Video Tag</string>
<key>CFBundleIdentifier</key><string>local.videotag</string>
<key>CFBundleExecutable</key><string>VideoTag</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>2.0</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSRemovableVolumesUsageDescription</key><string>Video Tag lit vos vidéos et planches sur le disque externe.</string>
</dict></plist>
EOF
codesign --force --sign - "$APP"
echo "$APP"
