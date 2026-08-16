#!/bin/bash
# Builds GODLister.app next to the project folder. Ad-hoc signed only - no
# Developer ID certificate is assumed. Gatekeeper will still block first
# launch; right-click > Open once to bypass, or notarize with a real
# certificate for real distribution (see README).
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"
APP_DIR="$PROJECT_DIR/../GODLister.app"

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

BUILD_DIR="$PROJECT_DIR/.build/release"
cp "$BUILD_DIR/GODLister" "$APP_DIR/Contents/MacOS/GODLister"
cp "$BUILD_DIR/GODLister_GODLister.bundle/gamelist_xbox360.csv" "$APP_DIR/Contents/Resources/gamelist_xbox360.csv"
cp "$BUILD_DIR/GODLister_GODLister.bundle/dlc_titles.csv" "$APP_DIR/Contents/Resources/dlc_titles.csv"
cp "$PROJECT_DIR/Packaging/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/PkgInfo" <<'EOF'
APPL????
EOF

cat > "$APP_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>GODLister</string>
    <key>CFBundleDisplayName</key>
    <string>GODLister</string>
    <key>CFBundleIdentifier</key>
    <string>com.camiburger.godlister</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleExecutable</key>
    <string>GODLister</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
EOF

# Resources must be in place under Contents/ BEFORE signing - a loose
# resource folder outside Contents/ breaks the code signature seal
# ("code has no resources but signature indicates they must be present").
codesign --force --sign - "$APP_DIR"
codesign --verify --strict "$APP_DIR"

echo "Built: $APP_DIR"
