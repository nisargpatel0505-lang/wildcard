#!/usr/bin/env bash
set -euo pipefail

repo_dir="${WILDCARD_REPO_DIR:-$HOME/wildcard}"
webroot="${WILDCARD_WEBROOT:-/var/www/wildcard}"

if [[ "${1:-}" != "--after-pull" ]]; then
  git -C "$repo_dir" pull --ff-only origin main
  exec "$repo_dir/deploy/update-pi.sh" --after-pull
fi

verify_package_source() {
  local package="$1" entry="$2"
  python3 - "$package" "$entry" "$repo_dir/www/index.html" <<'PY'
import hashlib
import sys
import zipfile

package, entry, source_path = sys.argv[1:]
source = open(source_path, 'rb').read()
with zipfile.ZipFile(package) as archive:
    embedded = archive.read(entry)
if embedded != source:
    print('Stale Android artifact:', package, file=sys.stderr)
    print('source  ', hashlib.sha256(source).hexdigest(), file=sys.stderr)
    print('embedded', hashlib.sha256(embedded).hexdigest(), file=sys.stderr)
    raise SystemExit(2)
PY
}

verify_package_source "$repo_dir/releases/WILDCARD-v6.9.14.apk" 'assets/public/index.html'
if [[ -f "$repo_dir/releases/WILDCARD-v6.9.14.aab" ]]; then
  verify_package_source "$repo_dir/releases/WILDCARD-v6.9.14.aab" 'base/assets/public/index.html'
fi

find_api_pid() {
  local pid="" command=""
  while read -r pid command; do
    if [[ "$command" == "/usr/bin/python3 $HOME/wildcard-api.py" ]]; then
      printf '%s' "$pid"
      return 0
    fi
  done < <(ps -u "$(id -u)" -o pid=,args=)
}

wait_for_api() {
  local previous_pid="$1" expected_marker="$2" require_board="${3:-false}" pid="" health="" date=""
  date="$(date -u +%F)"
  for _ in {1..40}; do
    pid="$(find_api_pid || true)"
    if [[ -n "$pid" && "$pid" != "$previous_pid" ]]; then
      health="$(curl -fsS http://127.0.0.1:8090/api/health 2>/dev/null || true)"
      if [[ "$health" == *"$expected_marker"* ]] &&
         { [[ "$require_board" != "true" ]] || [[ "$health" == *'"boardWritesReady":true'* ]]; } &&
         curl -fsS "http://127.0.0.1:8090/api/daily?date=$date" >/dev/null 2>&1; then
        return 0
      fi
    fi
    sleep 0.25
  done
  return 1
}

deploy_api() {
  local source="$repo_dir/deploy/wildcard-api.py"
  local report="$repo_dir/deploy/analytics-report.py"
  local target="$HOME/wildcard-api.py"
  local next="$HOME/.wildcard-api.py.next"
  local stamp="" backup="" old_pid="" failed_pid=""

  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$source"
  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$report"
  install -m 0755 "$report" "$HOME/wildcard-analytics-report"
  if [[ -f "$target" ]] && cmp -s "$source" "$target"; then return 0; fi

  if [[ "$(systemctl is-active wildcard-api.service 2>/dev/null || true)" != "active" ]] ||
     [[ "$(systemctl show wildcard-api.service -p Restart --value 2>/dev/null || true)" != "always" ]]; then
    echo "Refusing API update: wildcard-api.service is not active with Restart=always" >&2
    return 3
  fi
  old_pid="$(find_api_pid || true)"
  if [[ -z "$old_pid" ]]; then
    echo "Refusing API update: exact existing API process was not found" >&2
    return 3
  fi

  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  backup="$HOME/wildcard-api.py.before-$stamp"
  cp -p "$target" "$backup"
  for state in "$HOME/wildcard-daily-scores.json" "$HOME/wildcard-analytics.json"; do
    if [[ -f "$state" ]]; then cp -p "$state" "$state.before-$stamp"; chmod 0600 "$state" "$state.before-$stamp"; fi
  done
  install -m 0755 "$source" "$next"
  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$next"
  mv -f "$next" "$target"

  if ! kill "$old_pid" || ! wait_for_api "$old_pid" '"board":"authenticated-v2"' true; then
    echo "New WILDCARD API failed validation; restoring $backup" >&2
    install -m 0755 "$backup" "$target"
    failed_pid="$(find_api_pid || true)"
    if [[ -n "$failed_pid" ]]; then kill "$failed_pid" || true; fi
    if ! wait_for_api "$failed_pid" '"ok":true'; then
      echo "Rollback API did not recover; administrator action is required" >&2
      return 4
    fi
    return 3
  fi
}

deploy_api

install -d -m 0755 "$webroot/assets/art/backgrounds" "$webroot/assets/art/sly" "$webroot/assets/audio" "$webroot/fonts"
for artwork in "$repo_dir"/www/assets/art/backgrounds/*; do
  install -m 0644 "$artwork" "$webroot/assets/art/backgrounds/$(basename "$artwork")"
done
for artwork in "$repo_dir"/www/assets/art/sly/*.webp; do
  install -m 0644 "$artwork" "$webroot/assets/art/sly/$(basename "$artwork")"
done
for font in "$repo_dir"/www/fonts/*.ttf; do
  install -m 0644 "$font" "$webroot/fonts/$(basename "$font")"
done
install -m 0644 "$repo_dir/www/assets/art/wildcard-logo-v692.webp" "$webroot/assets/art/wildcard-logo-v692.webp"
install -m 0644 "$repo_dir/www/assets/art/wildcard-logo-boot.webp" "$webroot/assets/art/wildcard-logo-boot.webp"
install -m 0644 "$repo_dir/www/assets/audio/bit-shift-kevin-macleod-115bpm.mp3" "$webroot/assets/audio/bit-shift-kevin-macleod-115bpm.mp3"

install -m 0644 "$repo_dir/www/index.html" /tmp/game-upload.html
"$HOME/deploy-game.sh"

for asset in manifest.json sw.js privacy.html icon-192.png icon-512.png icon-maskable-512.png; do
  if [[ -f "$repo_dir/www/$asset" ]]; then
    install -m 0644 "$repo_dir/www/$asset" "$webroot/$asset"
  fi
done
install -d -m 0755 "$webroot/assets/video"
install -m 0644 "$repo_dir/www/assets/video/sly-single-tear.mp4" "$webroot/assets/video/sly-single-tear.mp4"

install -m 0644 "$repo_dir/releases/WILDCARD-v6.9.14.apk" "$webroot/WILDCARD-v6.9.14.apk"
install -m 0644 "$repo_dir/releases/WILDCARD-v6.9.14.apk" "$webroot/WILDCARD-v6.9.14-release.apk"
install -m 0644 "$repo_dir/releases/WILDCARD-v6.9.14.apk" "$webroot/WILDCARD-latest.apk"

sha256sum "$webroot/WILDCARD-v6.9.14.apk" "$webroot/WILDCARD-latest.apk"
echo "WILDCARD updated from GitHub: https://raspberrypi.tail20f574.ts.net"
