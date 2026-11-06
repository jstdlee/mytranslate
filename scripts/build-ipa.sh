#!/usr/bin/env bash
# Unsigned Release build for a real iPhone, packed as an .ipa (for sideloading tools that re-sign it).
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d OhMyTranslate.xcodeproj ] || xcodegen generate

xcodebuild build \
  -project OhMyTranslate.xcodeproj \
  -scheme OhMyTranslate \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" -quiet

rm -rf build/Payload build/OhMyTranslate-unsigned.ipa
mkdir -p build/Payload
cp -R build/device/Build/Products/Release-iphoneos/OhMyTranslate.app build/Payload/
(cd build && zip -qry OhMyTranslate-unsigned.ipa Payload)
ls -lh build/OhMyTranslate-unsigned.ipa
