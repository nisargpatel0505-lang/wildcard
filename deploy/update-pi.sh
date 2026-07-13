#!/usr/bin/env bash
set -euo pipefail

repo_dir="${WILDCARD_REPO_DIR:-$HOME/wildcard}"
webroot="${WILDCARD_WEBROOT:-/var/www/wildcard}"

git -C "$repo_dir" pull --ff-only origin main

install -m 0644 "$repo_dir/www/index.html" /tmp/game-upload.html
"$HOME/deploy-game.sh"

for asset in manifest.json sw.js icon-192.png icon-512.png icon-maskable-512.png; do
  if [[ -f "$repo_dir/www/$asset" ]]; then
    install -m 0644 "$repo_dir/www/$asset" "$webroot/$asset"
  fi
done

install -m 0644 "$repo_dir/releases/WILDCARD-v6.8.apk" "$webroot/WILDCARD-v6.8.apk"
install -m 0644 "$repo_dir/releases/WILDCARD-v6.8.apk" "$webroot/WILDCARD-v6.8-release.apk"
install -m 0644 "$repo_dir/releases/WILDCARD-v6.8.apk" "$webroot/WILDCARD-latest.apk"

sha256sum "$webroot/WILDCARD-v6.8.apk" "$webroot/WILDCARD-latest.apk"
echo "WILDCARD updated from GitHub: https://raspberrypi.tail20f574.ts.net"

