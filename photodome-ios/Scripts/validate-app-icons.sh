#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
icon_dir="$project_dir/PhotoDome/Assets.xcassets/AppIcon.appiconset"
catalog="$icon_dir/Contents.json"

expected=(
  "AppIcon.png"
  "AppIcon-dark.png"
  "AppIcon-tinted.png"
)

for filename in "${expected[@]}"; do
  path="$icon_dir/$filename"
  test -f "$path" || {
    echo "Missing $filename" >&2
    exit 1
  }

  width="$(sips -g pixelWidth "$path" | awk '/pixelWidth/ { print $2 }')"
  height="$(sips -g pixelHeight "$path" | awk '/pixelHeight/ { print $2 }')"
  alpha="$(sips -g hasAlpha "$path" | awk '/hasAlpha/ { print $2 }')"

  test "$width" = "1024" || {
    echo "$filename width is $width, expected 1024" >&2
    exit 1
  }
  test "$height" = "1024" || {
    echo "$filename height is $height, expected 1024" >&2
    exit 1
  }
  test "$alpha" = "no" || {
    echo "$filename contains an alpha channel" >&2
    exit 1
  }
  grep -q "\"filename\" : \"$filename\"" "$catalog" || {
    echo "$filename is not registered in Contents.json" >&2
    exit 1
  }
done

jq empty "$catalog"
echo "PhotoDome app icons: 3 registered, opaque 1024×1024 PNGs."
