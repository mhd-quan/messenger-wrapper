#!/usr/bin/env bash
# Builds build/Messenger.app (ad-hoc signed). With --install, also copies it
# to /Applications, quitting a running copy first.
set -euo pipefail

cd "$(dirname "$0")/.."

install=0
for arg in "$@"; do
  case "$arg" in
    --install) install=1 ;;
    *)
      echo "usage: $0 [--install]" >&2
      exit 2
      ;;
  esac
done

executable="MessengerWrapper"
app="build/Messenger.app"

swift build -c release
bin_dir="$(swift build -c release --show-bin-path)"

rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/$executable" "$app/Contents/MacOS/$executable"
cp Support/Info.plist "$app/Contents/Info.plist"
cp -R Resources/. "$app/Contents/Resources/"

if [ -f Resources/AppIcon.png ]; then
  iconset="build/AppIcon.iconset"
  rm -rf "$iconset"
  mkdir -p "$iconset"
  for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" Resources/AppIcon.png \
      --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" Resources/AppIcon.png \
      --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
  rm -rf "$iconset"
fi

codesign --force --sign - "$app"
echo "Built $app"

if [ "$install" -eq 1 ]; then
  osascript -e 'quit app "Messenger"' >/dev/null 2>&1 || true
  rm -rf /Applications/Messenger.app
  cp -R "$app" /Applications/
  echo "Installed /Applications/Messenger.app"
fi
