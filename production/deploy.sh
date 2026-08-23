#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${1:-${SCRIPT_DIR}/.env.production}"
WAIT_TIMEOUT="${2:-300}"

[[ "${WAIT_TIMEOUT}" =~ ^[1-9][0-9]*$ ]] || {
  printf 'Deployment wait timeout must be a positive number of seconds.\n' >&2
  exit 2
}

DOUBTFIRE_CONFIG_ONLY=0 "${SCRIPT_DIR}/validate.sh" "${ENV_FILE}"

ENV_FILE="$(cd -- "$(dirname -- "${ENV_FILE}")" && pwd)/$(basename -- "${ENV_FILE}")"

compose=("${SCRIPT_DIR}/compose.sh" --env-file "${ENV_FILE}")

"${compose[@]}" pull
if "${compose[@]}" up \
  --detach \
  --wait \
  --wait-timeout "${WAIT_TIMEOUT}" \
  --remove-orphans; then
  :
else
  rollout_status=$?
  printf 'Deployment did not become healthy; current state follows.\n' >&2
  "${compose[@]}" ps --all >&2 || true
  "${compose[@]}" logs \
    --no-color \
    --tail 100 \
    migrate apiserver webserver proxy sidekiq pdfgen >&2 || true
  exit "${rollout_status}"
fi
"${compose[@]}" ps
