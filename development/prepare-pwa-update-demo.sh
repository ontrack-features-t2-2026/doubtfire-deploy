#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
deploy_root=$(cd -- "$script_dir/.." && pwd)
web_root=$(cd -- "$deploy_root/../doubtfire-web" && pwd)
data_root="$deploy_root/data/pwa-update-demo"
compose=(
  docker compose -p notifications-demo
  -f "$script_dir/docker-compose.yml"
  -f "$script_dir/docker-compose.local-paths.yml"
)

prepare() {
  "${compose[@]}" run --rm --no-deps \
    -e NODE_OPTIONS=--max_old_space_size=3072 \
    doubtfire-web npm run deploy

  browser_dir="$web_root/dist/browser"
  if [ ! -f "$browser_dir/index.html" ]; then
    printf 'Production browser output was not found at %s\n' "$browser_dir" >&2
    exit 1
  fi

  run_name="run-$(date +%Y%m%d-%H%M%S)-$$"
  run_dir="$data_root/$run_name"
  mkdir -p "$run_dir/version-a" "$run_dir/version-b"

  marker='<div id="notification-demo-build" style="position:fixed;right:12px;bottom:12px;z-index:10000;border-radius:4px;background:#111827;color:white;padding:6px 10px;font:600 12px/1.2 sans-serif">Notification demo build A</div>'
  DEMO_MARKER="$marker" perl -0pi -e 's#</body>#$ENV{DEMO_MARKER}</body>#' "$browser_dir/index.html"
  "${compose[@]}" run --rm --no-deps doubtfire-web \
    npx ngsw-config dist/browser ngsw-config.json
  cp -R "$browser_dir/." "$run_dir/version-a/"

  perl -0pi -e 's/Notification demo build A/Notification demo build B/' "$browser_dir/index.html"
  "${compose[@]}" run --rm --no-deps doubtfire-web \
    npx ngsw-config dist/browser ngsw-config.json
  cp -R "$browser_dir/." "$run_dir/version-b/"

  mkdir -p "$data_root"
  ln -sfn "$run_name/version-a" "$data_root/current"
  "${compose[@]}" --profile pwa-update-demo up -d pwa-update-demo

  printf 'Version A is live at http://localhost:4500\n'
  printf 'When the A tab is open, run: %s b\n' "$0"
}

switch_version() {
  version=$1
  current_target=$(readlink "$data_root/current" 2>/dev/null || true)
  if [ -z "$current_target" ]; then
    printf 'No prepared PWA update demo. Run: %s prepare\n' "$0" >&2
    exit 1
  fi

  run_name=${current_target%%/version-*}
  target="$run_name/version-$version"
  if [ ! -d "$data_root/$target" ]; then
    printf 'Prepared version %s was not found.\n' "$version" >&2
    exit 1
  fi

  ln -sfn "$target" "$data_root/current"
  printf 'Version %s is now served at http://localhost:4500\n' "$version"
}

case "${1:-prepare}" in
  prepare) prepare ;;
  a) switch_version a ;;
  b) switch_version b ;;
  stop) "${compose[@]}" --profile pwa-update-demo stop pwa-update-demo ;;
  *)
    printf 'Usage: %s [prepare|a|b|stop]\n' "$0" >&2
    exit 2
    ;;
esac
