#!/bin/sh
# Builds Touch-Tab.app and Touch-Tab.dmg with the Command Line Tools only, no Xcode needed.
# Usage: scripts/build-dmg.sh
# Output: build/Release/Touch-Tab.app and build/Touch-Tab.dmg
set -eu

cd "$(dirname "$0")/.."
ROOT=$PWD
NAME=Touch-Tab
SRC="$ROOT/Touch-Tab"
ASSETS="$SRC/Assets.xcassets"
BUILD="$ROOT/build"
APP="$BUILD/Release/$NAME.app"
DMG="$BUILD/$NAME.dmg"
MIN_MACOS=10.15

setting() {
    grep -m1 "$1 = " "$NAME.xcodeproj/project.pbxproj" | sed -E 's/.*= "?([^";]*)"?;/\1/'
}
VERSION=$(setting MARKETING_VERSION)
BUILD_NUMBER=$(setting CURRENT_PROJECT_VERSION)
BUNDLE_ID=$(setting PRODUCT_BUNDLE_IDENTIFIER)
COPYRIGHT=$(setting INFOPLIST_KEY_NSHumanReadableCopyright)

echo "Building $NAME $VERSION ($BUILD_NUMBER)"
rm -rf "$APP" "$DMG" "$BUILD/obj"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD/obj"

# Compile every architecture the SDK supports and merge them into a universal binary.
SLICES=""
for ARCH in arm64 x86_64; do
    OUT="$BUILD/obj/$NAME-$ARCH"
    if swiftc -O -swift-version 5 -module-name Touch_Tab \
        -target "$ARCH-apple-macos$MIN_MACOS" \
        -o "$OUT" "$SRC"/*.swift; then
        SLICES="$SLICES $OUT"
    else
        echo "warning: couldn't build for $ARCH, skipping it"
    fi
done
if [ -z "$SLICES" ]; then
    echo "error: build failed" >&2
    exit 1
fi
# shellcheck disable=SC2086
lipo -create $SLICES -output "$APP/Contents/MacOS/$NAME"

# Without Xcode the asset catalog can't be compiled, so ship the images as plain resources.
ICONSET="$BUILD/obj/AppIcon.iconset"
mkdir -p "$ICONSET"
for SIZE in 16 32 128 256 512; do
    cp "$ASSETS/AppIcon.appiconset/AppIcon_${SIZE}x${SIZE}.png" "$ICONSET/icon_${SIZE}x${SIZE}.png"
    cp "$ASSETS/AppIcon.appiconset/AppIcon_$((SIZE * 2))x$((SIZE * 2)).png" "$ICONSET/icon_${SIZE}x${SIZE}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

RES="$APP/Contents/Resources"
cp "$ASSETS/StatusIcon.imageset/StatusIcon_16x16.png" "$RES/StatusIcon.png"
cp "$ASSETS/StatusIcon.imageset/StatusIcon_32x32.png" "$RES/StatusIcon@2x.png"
cp "$ASSETS/StatusIcon-Warning.imageset/StatusIcon-Warning_22x22.png" "$RES/StatusIcon-Warning.png"
cp "$ASSETS/StatusIcon-Warning.imageset/StatusIcon-Warning_44x44.png" "$RES/StatusIcon-Warning@2x.png"
cp "$ASSETS/MenuItem-Warning.imageset/MenuItem-Warning_16x16.png" "$RES/MenuItem-Warning.png"
cp "$ASSETS/MenuItem-Warning.imageset/MenuItem-Warning_32x32.png" "$RES/MenuItem-Warning@2x.png"
cp "$ASSETS/MenuItem-Warning.imageset/MenuItem-Warning_48x48.png" "$RES/MenuItem-Warning@3x.png"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>$NAME</string>
	<key>CFBundleExecutable</key>
	<string>$NAME</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>$BUNDLE_ID</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$NAME</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleSupportedPlatforms</key>
	<array>
		<string>MacOSX</string>
	</array>
	<key>CFBundleVersion</key>
	<string>$BUILD_NUMBER</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.productivity</string>
	<key>LSMinimumSystemVersion</key>
	<string>$MIN_MACOS</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>$COPYRIGHT</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature with the sandbox entitlement and the hardened runtime, same as the Xcode build.
codesign --force --sign - --options runtime --entitlements "$SRC/$NAME.entitlements" "$APP"
codesign --verify --deep --strict "$APP"

# Disk image with a shortcut to Applications so the app can be dragged there.
STAGING="$BUILD/obj/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
hdiutil create -volname "$NAME" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null

lipo -info "$APP/Contents/MacOS/$NAME"
echo "App: $APP"
echo "DMG: $DMG"
