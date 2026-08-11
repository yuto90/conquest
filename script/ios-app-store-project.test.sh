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

  if [[ "$device_family" != "1" ]]; then
    printf 'Runner must be iPhone-only for %s builds; TARGETED_DEVICE_FAMILY was %s\n' \
      "$configuration" "${device_family:-unset}" >&2
    exit 1
  fi
done

printf 'iOS App Store project tests passed\n'
