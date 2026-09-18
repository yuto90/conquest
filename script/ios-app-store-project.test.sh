#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
project="$repo_root/ios/Runner.xcodeproj"

for configuration in Debug Release Profile; do
  device_family="$({
    xcodebuild \
      -project "$project" \
      -target Runner \
      -configuration "$configuration" \
      -showBuildSettings
  } | awk -F ' = ' '$1 ~ /^[[:space:]]*TARGETED_DEVICE_FAMILY$/ { print $2; exit }')"

  if [[ "$device_family" != "1,2" ]]; then
    printf 'Runner must support iPhone and iPad for %s builds; TARGETED_DEVICE_FAMILY was %s\n' \
      "$configuration" "${device_family:-unset}" >&2
    exit 1
  fi
done

if grep -q '<key>UIDeviceFamily</key>' "$repo_root/ios/Runner/Info.plist"; then
  echo 'UIDeviceFamily must be generated from TARGETED_DEVICE_FAMILY, not written to source Info.plist' >&2
  exit 1
fi

python3 - "$repo_root/ios/Runner/Info.plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as file:
    info = plistlib.load(file)

if info.get("UISupportedInterfaceOrientations") != ["UIInterfaceOrientationPortrait"]:
    raise SystemExit("iPhone orientations must remain portrait-only")
if info.get("UISupportedInterfaceOrientations~ipad") != [
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
]:
    raise SystemExit("iPad orientations must include portrait and both landscape directions")
PY

printf 'iOS App Store project tests passed\n'
