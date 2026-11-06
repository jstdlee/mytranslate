#!/usr/bin/env bash
# Build the app and its translation extension, run the UI tests on a simulator, collect screenshots.
# Runs on macOS (GitHub Actions or a Mac). Xcode is macOS-only.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate

IPHONE=$(python3 scripts/pick-simulator.py iphone)
rm -rf screenshots build/Result.xcresult
mkdir -p screenshots build

# TEST_RUNNER_ variables reach the test process without the prefix.
export TEST_RUNNER_SCREENSHOT_DIR="$PWD/screenshots"

set +e
xcodebuild test \
  -project OhMyTranslate.xcodeproj \
  -scheme OhMyTranslate \
  -destination "id=$IPHONE" \
  -derivedDataPath build/sim \
  -resultBundlePath build/Result.xcresult \
  -retry-tests-on-failure -test-iterations 2 \
  CODE_SIGNING_ALLOWED=NO 2>&1 \
  | tee build/xcodebuild.log \
  | grep -iE --line-buffered '(error:|warning: .*(OhMyTranslate|TranslateExtension)|test case .*(passed|failed)|Executed|\*\* )'
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ] && [ -d build/Result.xcresult ]; then
  xcrun xcresulttool get test-results summary --path build/Result.xcresult 2>/dev/null \
    | python3 -c 'import json,sys
d=json.load(sys.stdin)
for f in d.get("testFailures", []):
    print("FAILED", f.get("targetName",""), f.get("testName",""), "::", f.get("failureText",""))' || true
fi

# The extension must be inside the app, or iOS never offers it as the default translation app.
app=$(find build/sim/Build/Products -maxdepth 2 -name OhMyTranslate.app -type d | head -1)
if [ -n "$app" ]; then
  echo "Extensions in $app:"
  find "$app" -name '*.appex' -maxdepth 3
  appex=$(find "$app" -name 'TranslateExtension.appex' -maxdepth 3 | head -1)
  if [ -z "$appex" ]; then echo "error: TranslateExtension.appex is not embedded"; status=1
  else /usr/libexec/PlistBuddy -c 'Print :EXAppExtensionAttributes' "$appex/Info.plist" || status=1
  fi
fi

echo "Screenshots:"
ls -1 screenshots || true
exit "$status"
