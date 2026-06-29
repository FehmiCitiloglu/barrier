#!/bin/sh
set -eu

DMG_PATH=${1:?Usage: notarize_dmg.sh /path/to/Barrier.dmg}
PROFILE=${BARRIER_NOTARY_PROFILE:?Set BARRIER_NOTARY_PROFILE to a notarytool keychain profile}

xcrun notarytool submit "$DMG_PATH" --keychain-profile "$PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"
