#!/bin/sh
set -eu

ARTIFACT=${1:?Usage: validate_artifact.sh /path/to/Barrier.app-or-dmg}

case "$ARTIFACT" in
    *.app)
        codesign -dvvv --entitlements :- "$ARTIFACT"
        codesign --verify --deep --strict --verbose=2 "$ARTIFACT"
        spctl -a -vv "$ARTIFACT"
        ;;
    *.dmg)
        xcrun stapler validate "$ARTIFACT"
        spctl -a -vv -t open "$ARTIFACT"
        ;;
    *)
        echo "Unsupported artifact type: $ARTIFACT" >&2
        exit 1
        ;;
esac
