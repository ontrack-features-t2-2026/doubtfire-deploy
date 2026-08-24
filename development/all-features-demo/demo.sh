#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
development_dir="$(cd "${script_dir}/.." && pwd)"

compose=(
  docker compose
  -p all-features-demo
  -f "${development_dir}/docker-compose.yml"
  -f "${development_dir}/docker-compose.local-paths.yml"
  -f "${script_dir}/compose.yml"
)

usage() {
  echo "Usage: $0 {start|seed|status|logs|stop|config|destroy}"
  echo
  echo "Set DF_DEMO_API_PATH and DF_DEMO_WEB_PATH to use isolated worktrees."
  echo "The destroy command also requires ALL_FEATURES_DEMO_CONFIRM_DESTROY=1."
}

case "${1:-}" in
  start)
    "${compose[@]}" up -d --build
    ;;
  seed)
    "${compose[@]}" run --rm \
      -e DF_DEMO_DATA_PROFILE=all-features \
      doubtfire-api bundle exec rake db:migrate db:init db:all_features_demo
    ;;
  status)
    "${compose[@]}" ps -a
    ;;
  logs)
    "${compose[@]}" logs --tail 200 doubtfire-api doubtfire-sidekiq doubtfire-web
    ;;
  stop)
    "${compose[@]}" stop
    ;;
  config)
    "${compose[@]}" config
    ;;
  destroy)
    if [[ "${ALL_FEATURES_DEMO_CONFIRM_DESTROY:-}" != "1" ]]; then
      echo "Refusing to remove volumes without ALL_FEATURES_DEMO_CONFIRM_DESTROY=1."
      exit 2
    fi

    "${compose[@]}" down --volumes --remove-orphans
    ;;
  *)
    usage
    exit 1
    ;;
esac
