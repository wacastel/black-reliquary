#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
DEST="$PWD/Black Reliquary.app"
RELIQUARY_STAGE="$(mktemp -d "${TMPDIR:-/tmp/}black-reliquary.XXXXXX")"
trap 'rm -rf "$RELIQUARY_STAGE"' EXIT
APP="$RELIQUARY_STAGE/Black Reliquary.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -swift-version 5 -target arm64-apple-macosx14.0 -framework AppKit -framework SceneKit -framework AVFoundation -framework QuartzCore -framework Metal Source/*.swift -o "$APP/Contents/MacOS/BlackReliquary"
cp Resources/*.wav "$APP/Contents/Resources/"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>BlackReliquary</string>
<key>CFBundleIdentifier</key><string>local.codex.blackreliquary</string>
<key>CFBundleName</key><string>Black Reliquary</string>
<key>CFBundleDisplayName</key><string>Black Reliquary</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
<key>NSHumanReadableCopyright</key><string>Original prototype created with Codex. 2026.</string>
</dict></plist>
PLIST
xattr -dr com.apple.FinderInfo "$APP" 2>/dev/null || true
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
ditto --noextattr "$APP" "$DEST"
xattr -dr com.apple.FinderInfo "$DEST" 2>/dev/null || true
codesign --verify --deep --strict "$DEST"
echo "Built $DEST"
