#!/bin/sh
set -eu

APP_PATH=${1:?Usage: sign_bundle.sh /path/to/Barrier.app}
IDENTITY=${BARRIER_DEVELOPER_ID_APP:?Set BARRIER_DEVELOPER_ID_APP to a Developer ID Application identity}
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ENTITLEMENTS=${BARRIER_ENTITLEMENTS:-"$SCRIPT_DIR/Barrier.entitlements"}

if [ ! -d "$APP_PATH/Contents" ]; then
    echo "Not an app bundle: $APP_PATH" >&2
    exit 1
fi

find "$APP_PATH/Contents/Frameworks" -type f \( -name "*.dylib" -o -perm -111 \) -print 2>/dev/null | while IFS= read -r item; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
done

find "$APP_PATH/Contents/PlugIns" -type f -print 2>/dev/null | while IFS= read -r item; do
    codesign --force --options runtime --timestamp --sign "$IDENTITY" "$item"
done

codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$IDENTITY" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv "$APP_PATH"
