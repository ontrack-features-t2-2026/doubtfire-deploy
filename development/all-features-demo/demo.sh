#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
development_dir="$(cd "${script_dir}/.." && pwd)"
repository_dir="$(cd "${development_dir}/.." && pwd)"

resolve_source_path() {
  local label="$1"
  local override_name="$2"
  local sibling_name="$3"
  local required_file="$4"
  local override_value="${!override_name:-}"
  local candidate

  if [[ -n "${override_value}" ]]; then
    candidate="${override_value}"
  elif [[ -f "${repository_dir}/../${sibling_name}/${required_file}" ]]; then
    candidate="${repository_dir}/../${sibling_name}"
  else
    candidate="${repository_dir}/${sibling_name}"
  fi

  if [[ ! -d "${candidate}" || ! -f "${candidate}/${required_file}" ]]; then
    printf 'Unable to locate the %s source with required file %s.\n' "${label}" "${required_file}" >&2
    printf 'Set %s to a complete checkout, or initialise the %s submodule.\n' "${override_name}" "${sibling_name}" >&2
    return 1
  fi

  (cd "${candidate}" && pwd)
}

DF_DEMO_API_PATH="$(resolve_source_path API DF_DEMO_API_PATH doubtfire-api lib/tasks/all_features_demo.rake)"
DF_DEMO_WEB_PATH="$(resolve_source_path web DF_DEMO_WEB_PATH doubtfire-web src/app/demo/demo-mode.store.ts)"
export DF_DEMO_API_PATH DF_DEMO_WEB_PATH

compose=(
  docker compose
  -p all-features-demo
  -f "${development_dir}/docker-compose.yml"
  -f "${development_dir}/docker-compose.local-paths.yml"
  -f "${script_dir}/compose.yml"
)

usage() {
  echo "Usage: $0 {prepare|start|seed|verify|status|logs|stop|config|sources|destroy}"
  echo
  echo "prepare builds, starts, seeds, restarts, and verifies the complete demo."
  echo "Source order: explicit DF_DEMO_*_PATH, sibling checkout, deploy submodule."
  echo "The destroy command also requires ALL_FEATURES_DEMO_CONFIRM_DESTROY=1."
}

seed_demo() {
  "${compose[@]}" run --rm \
    -e DF_DEMO_DATA_PROFILE=all-features \
    doubtfire-api bundle exec rake db:migrate db:init db:all_features_demo
}

verify_demo() {
  "${compose[@]}" run --rm \
    -e DF_DEMO_DATA_PROFILE=all-features \
    doubtfire-api bundle exec rake db:all_features_demo_verify
}

case "${1:-}" in
  prepare)
    # Build first so Compose cannot satisfy the guarded seed from an unrelated
    # mutable local image. Start only infrastructure until the brand-new
    # database is migrated and seeded; application readers start afterwards.
    "${compose[@]}" build doubtfire-api doubtfire-web
    "${compose[@]}" up -d dev-db redis-sidekiq mailpit
    seed_demo
    "${compose[@]}" up -d --wait --wait-timeout 300
    verify_demo
    "${compose[@]}" ps -a
    ;;
  start)
    "${compose[@]}" up -d --build
    ;;
  seed)
    seed_demo
    # A fresh database can make an eagerly started API or worker exit before
    # the seed finishes. Ensure the complete demo is running afterwards.
    "${compose[@]}" up -d --wait --wait-timeout 300
    ;;
  verify)
    verify_demo
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
    "${compose[@]}" config "${@:2}"
    ;;
  sources)
    printf 'API source: %s\n' "${DF_DEMO_API_PATH}"
    printf 'Web source: %s\n' "${DF_DEMO_WEB_PATH}"
    git -C "${DF_DEMO_API_PATH}" rev-parse HEAD 2>/dev/null | sed 's/^/API revision: /' || true
    git -C "${DF_DEMO_WEB_PATH}" rev-parse HEAD 2>/dev/null | sed 's/^/Web revision: /' || true
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
