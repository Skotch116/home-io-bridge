#!/bin/bash
# Builds "mac/build/Home.io Bridge.app" for this Mac: a menu bar app (no Dock icon), signed ad hoc for local runs.
# The engine (this repository's `cargo build --release -p play-on-air`, run from the repository's top folder) goes inside it.
# `mac/tools/make_app.sh install` also copies the app to /Applications, where Open at Login expects it.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
APP="build/Home.io Bridge.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HomeIOBridge "$APP/Contents/MacOS/HomeIOBridge"
ENGINE="../target/release/play-on-air"
[ -x "$ENGINE" ] || { echo "no engine at $ENGINE: build it first: cargo build --release -p play-on-air"; exit 1; }
cp "$ENGINE" "$APP/Contents/MacOS/play-on-air"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key><string>io.github.skotch116.homeio-bridge</string>
	<key>CFBundleName</key><string>Home.io Bridge</string>
	<key>CFBundleExecutable</key><string>HomeIOBridge</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSUIElement</key><true/>
	<key>NSLocalNetworkUsageDescription</key><string>Home.io Bridge looks for Google speakers on your network so you can play to them with AirPlay.</string>
	<key>NSBonjourServices</key><array><string>_googlecast._tcp</string><string>_airplay._tcp</string><string>_raop._tcp</string><string>_homeio-bridge._tcp</string></array>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP/Contents/MacOS/play-on-air"
codesign --force --sign - "$APP"
echo "built $APP"
if [ "${1:-}" = install ]; then
	rm -rf "/Applications/Home.io Bridge.app"
	ditto "$APP" "/Applications/Home.io Bridge.app"
	echo "installed /Applications/Home.io Bridge.app"
fi
