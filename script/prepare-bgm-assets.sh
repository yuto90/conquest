#!/usr/bin/env bash

set -euo pipefail

files=(metropolis_destruction.mp3 tense_tactics.mp3)
hash_names=(BGM_MENU_SHA256 BGM_BATTLE_SHA256)
url_names=(BGM_MENU_URL BGM_BATTLE_URL)

fail() {
  printf 'BGM assets: %s\n' "$1" >&2
  exit 1
}

verify_assets() {
  local directory="$1" index path expected actual
  for index in 0 1; do
    path="$directory/${files[$index]}"
    [[ -s "$path" ]] || fail "Missing or empty ${files[$index]}"
    expected="${!hash_names[$index]}"
    expected="$(printf '%s' "$expected" | tr '[:upper:]' '[:lower:]')"
    actual="$(shasum -a 256 "$path")"
    [[ "${actual%% *}" == "$expected" ]] || fail "SHA-256 mismatch for ${files[$index]}"
  done
}

[[ $# -ge 1 && $# -le 2 ]] || fail 'Usage: prepare-bgm-assets.sh DESTINATION [SOURCE] or --verify DIRECTORY'
for name in "${hash_names[@]}"; do
  value="${!name:-}"
  [[ "$value" =~ ^[[:xdigit:]]{64}$ ]] || fail "Set $name to the approved file SHA-256"
done

if [[ "$1" == --verify ]]; then
  [[ $# -eq 2 ]] || fail '--verify requires a directory'
  verify_assets "$2"
  printf 'Bundled BGM assets verified\n'
  exit 0
fi

destination="$1"
source_directory="${2:-}"
if [[ -z "$source_directory" ]]; then
  for name in "${url_names[@]}"; do
    value="${!name:-}"
    [[ "$value" == https://* ]] || fail "Set $name to an approved protected HTTPS download URL"
  done
fi

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
for index in 0 1; do
  filename="${files[$index]}"
  if [[ -n "$source_directory" ]]; then
    [[ -f "$source_directory/$filename" ]] || fail "Missing source $filename"
    cp "$source_directory/$filename" "$staging/$filename"
  else
    name="${url_names[$index]}"
    curl --silent --fail --location --proto '=https' --proto-redir '=https' \
      --connect-timeout 15 --max-time 120 --max-filesize 20000000 \
      --output "$staging/$filename" "${!name}" || fail "Could not download $filename"
  fi
done
verify_assets "$staging"
mkdir -p "$destination"
cp "$staging/${files[0]}" "$staging/${files[1]}" "$destination/"
printf 'Approved menu and battle BGM assets prepared\n'
