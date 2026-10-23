#!/bin/bash
set -e
cd "$(dirname "$0")"
swift build -c release
APP=build/DynamicIsland.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DynamicIsland "$APP/Contents/MacOS/DynamicIsland"
cp Info.plist "$APP/Contents/Info.plist"
echo "Built $APP"
echo "Run it with: open $APP"
