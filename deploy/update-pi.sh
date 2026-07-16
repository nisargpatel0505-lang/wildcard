#!/usr/bin/env bash
set -euo pipefail

repo_dir="${WILDCARD_REPO_DIR:-$HOME/wildcard}"
webroot="${WILDCARD_WEBROOT:-/var/www/wildcard}"

git -C "$repo_dir" pull --ff-only origin main

install -d -m 0755 "$webroot/assets/art/backgrounds" "$webroot/assets/audio"
for artwork in "$repo_dir"/www/assets/art/backgrounds/*.webp; do
  install -m 0644 "$artwork" "$webroot/assets/art/backgrounds/$(basename "$artwork")"
done
install -m 0644 "$repo_dir/www/assets/art/wildcard-logo-v692.webp" "$webroot/assets/art/wildcard-logo-v692.webp"
install -m 0644 "$repo_dir/www/assets/audio/bit-shift-kevin-macleod-115bpm.mp3" "$webroot/assets/audio/bit-shift-kevin-macleod-115bpm.mp3"

install -m 0644 "$repo_dir/www/index.html" /tmp/game-upload.html
"$HOME/deploy-game.sh"

for asset in manifest.json sw.js icon-192.png icon-512.png icon-maskable-512.png; do
  if [[ -f "$repo_dir/www/$asset" ]]; then
    install -m 0644 "$repo_dir/www/$asset" "$webroot/$asset"
  fi
done

install -m 0644 "$repo_dir/releases/WILDCARD-v6.9.8.apk" "$webroot/WILDCARD-v6.9.8.apk"
install -m 0644 "$repo_dir/releases/WILDCARD-v6.9.8.apk" "$webroot/WILDCARD-v6.9.8-release.apk"
install -m 0644 "$repo_dir/releases/WILDCARD-v6.9.8.apk" "$webroot/WILDCARD-latest.apk"

sha256sum "$webroot/WILDCARD-v6.9.8.apk" "$webroot/WILDCARD-latest.apk"
echo "WILDCARD updated from GitHub: https://raspberrypi.tail20f574.ts.net"
