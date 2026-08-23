#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PRODUCTION_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
# Unix socket paths are short on some platforms (notably macOS), so keep this
# fixture directly under /tmp instead of a potentially long TMPDIR path.
FIXTURE_DIR="$(mktemp -d "/tmp/df-production-test.XXXXXX")"
cleanup() {
  rm -rf -- "${FIXTURE_DIR}"
}
trap cleanup EXIT INT TERM

HOSTNAME_UNDER_TEST=ontrack.test.edu.au
CERTIFICATE_PATH="${FIXTURE_DIR}/fullchain.pem"
PRIVATE_KEY_PATH="${FIXTURE_DIR}/private.key"
BASE_ENV="${FIXTURE_DIR}/valid.env"

mkdir -p \
  "${FIXTURE_DIR}/student-work" \
  "${FIXTURE_DIR}/logs" \
  "${FIXTURE_DIR}/mariadb" \
  "${FIXTURE_DIR}/redis" \
  "${FIXTURE_DIR}/student-work/jplag" \
  "${FIXTURE_DIR}/student-work/archive/jplag"

openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout "${PRIVATE_KEY_PATH}" \
  -out "${CERTIFICATE_PATH}" \
  -subj "/CN=${HOSTNAME_UNDER_TEST}" \
  -addext "subjectAltName=DNS:${HOSTNAME_UNDER_TEST}" \
  >/dev/null 2>&1
chmod 600 "${PRIVATE_KEY_PATH}"

# Compose rendering does not contact the daemon. CI uses config-only mode for
# its fixture and separately verifies that the live preflight remains
# fail-closed when the standard local daemon socket is unavailable.
export DOUBTFIRE_CONFIG_ONLY=1

cat > "${FIXTURE_DIR}/aliases" <<'EOF'
root: operations@test.edu.au
EOF
cat > "${FIXTURE_DIR}/msmtprc" <<'EOF'
defaults
auth on
tls on
account server
host smtp.test.edu.au
port 587
from ontrack@test.edu.au
user ontrack-service
password fixture-only-random-value
account default : server
EOF
chmod 600 "${FIXTURE_DIR}/msmtprc"

DIGEST_ONE="sha256:1111111111111111111111111111111111111111111111111111111111111111"
DIGEST_TWO="sha256:2222222222222222222222222222222222222222222222222222222222222222"
DIGEST_THREE="sha256:3333333333333333333333333333333333333333333333333333333333333333"

cat > "${BASE_ENV}" <<EOF
COMPOSE_PROJECT_NAME=doubtfire-production-test
SERVER_NAME=${HOSTNAME_UNDER_TEST}
DF_INSTITUTION_HOST=https://${HOSTNAME_UNDER_TEST}
TZ=Australia/Melbourne
CLIENT_MAX_BODY_SIZE=1g
PROXY_IMAGE=nginx@${DIGEST_ONE}
MARIADB_IMAGE=mariadb@${DIGEST_TWO}
REDIS_IMAGE=redis@${DIGEST_THREE}
DOCKER_SOCKET_PROXY_IMAGE=haproxy:3.2-alpine@${DIGEST_ONE}
DOUBTFIRE_API_IMAGE=lmsdoubtfire/apiserver@${DIGEST_TWO}
DOUBTFIRE_APP_IMAGE=lmsdoubtfire/appserver@${DIGEST_THREE}
DOUBTFIRE_WEB_IMAGE=lmsdoubtfire/doubtfire-web@${DIGEST_ONE}
TEXLIVE_IMAGE=lmsdoubtfire/formatif-latex@${DIGEST_TWO}
JPLAG_IMAGE=lmsdoubtfire/doubtfire-jplag@${DIGEST_THREE}
STUDENT_WORK_PATH=${FIXTURE_DIR}/student-work
DOUBTFIRE_LOG_PATH=${FIXTURE_DIR}/logs
MARIADB_DATA_PATH=${FIXTURE_DIR}/mariadb
REDIS_DATA_PATH=${FIXTURE_DIR}/redis
JPLAG_REPORT_PATH=${FIXTURE_DIR}/student-work/jplag
JPLAG_ARCHIVE_REPORT_PATH=${FIXTURE_DIR}/student-work/archive/jplag
TLS_CERTIFICATE_PATH=${CERTIFICATE_PATH}
TLS_PRIVATE_KEY_PATH=${PRIVATE_KEY_PATH}
ALIASES_PATH=${FIXTURE_DIR}/aliases
MSMTPRC_PATH=${FIXTURE_DIR}/msmtprc
DOCKER_SOCKET_PATH=/var/run/docker.sock
MARIADB_DATABASE=doubtfire
MARIADB_USER=dfire
MARIADB_PASSWORD=fixture-database-password-123456789
MARIADB_ROOT_PASSWORD=fixture-root-password-987654321
DF_SECRET_KEY_BASE=base_0123456789abcdef0123456789abcdef
DF_SECRET_KEY_ATTR=attr_0123456789abcdef0123456789abcdef
DF_SECRET_KEY_DEVISE=devise_0123456789abcdef0123456789abcdef
DF_SECRET_KEY_MOSS=
DF_ENCRYPTION_PRIMARY_KEY=primary_0123456789abcdef0123456789abcdef
DF_ENCRYPTION_DETERMINISTIC_KEY=deterministic_0123456789abcdef0123456789abcdef
DF_ENCRYPTION_KEY_DERIVATION_SALT=salt_0123456789abcdef0123456789abcdef
DF_INSTITUTION_PRODUCT_NAME=OnTrack
DF_INSTITUTION_SETTINGS_RB=no_institution_setting.rb
DF_INSTITUTION_EMAIL_DOMAIN=test.edu.au
DF_INSTITUTION_EMAIL_SENDER=ontrack@test.edu.au
DF_INSTITUTION_NAME=Test University
DF_AUTH_METHOD=saml
DF_AAF_ISSUER_URL=
DF_AAF_AUDIENCE_URL=
DF_AAF_CALLBACK_URL=
DF_AAF_IDENTITY_PROVIDER_URL=
DF_AAF_UNIQUE_URL=
DF_AAF_AUTH_SIGNOUT_URL=
DF_SECRET_KEY_AAF=
DF_SAML_METADATA_URL=https://identity.test.edu.au/metadata
DF_SAML_CONSUMER_SERVICE_URL=https://${HOSTNAME_UNDER_TEST}/api/auth/jwt
DF_SAML_SP_ENTITY_ID=https://${HOSTNAME_UNDER_TEST}
DF_SAML_IDP_TARGET_URL=https://identity.test.edu.au/saml2
DF_SAML_IDP_SAML_NAME_IDENTIFIER_FORMAT=urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress
DF_LDAP_HOST=
DF_LDAP_PORT=
DF_LDAP_ATTRIBUTE=
DF_LDAP_BASE=
DF_LDAP_SSL=true
DF_LDAP_USE_ADMIN_TO_BIND=false
DF_LDAP_ADMIN_USER=
DF_LDAP_ADMIN_PWD=
TEXLIVE_MEMORY_LIMIT=2g
TEXLIVE_CPU_LIMIT=2
TEXLIVE_PIDS_LIMIT=256
JPLAG_MEMORY_LIMIT=4g
JPLAG_CPU_LIMIT=2
JPLAG_PIDS_LIMIT=256
DF_MAIL_PERFORM_DELIVERIES=yes
DF_MAIL_DELIVERY_METHOD=smtp
DF_SMTP_ADDRESS=smtp.test.edu.au
DF_SMTP_PORT=587
DF_SMTP_DOMAIN=test.edu.au
DF_SMTP_USERNAME=ontrack-service
DF_SMTP_PASSWORD=fixture-smtp-password
DF_SMTP_AUTHENTICATION=plain
OVERSEER_ENABLED=0
EOF
chmod 600 "${BASE_ENV}"

replace_value() {
  local file="$1"
  local key="$2"
  local value="$3"
  local replacement="${file}.replacement"
  awk -v key="${key}" -v value="${value}" '
    index($0, key "=") == 1 { $0 = key "=" value }
    { print }
  ' "${file}" > "${replacement}"
  mv "${replacement}" "${file}"
  chmod 600 "${file}"
}

expect_failure() {
  local name="$1"
  local key="$2"
  local value="$3"
  local expected="$4"
  local fixture="${FIXTURE_DIR}/${name}.env"
  local output

  cp "${BASE_ENV}" "${fixture}"
  replace_value "${fixture}" "${key}" "${value}"

  if output="$("${PRODUCTION_DIR}/validate.sh" "${fixture}" 2>&1)"; then
    printf 'Expected %s to fail.\n' "${name}" >&2
    exit 1
  fi
  printf '%s' "${output}" | grep -Fq "${expected}" || {
    printf 'Unexpected %s failure: %s\n' "${name}" "${output}" >&2
    exit 1
  }
  printf 'ok - %s\n' "${name}"
}

"${PRODUCTION_DIR}/validate.sh" "${BASE_ENV}" >/dev/null
printf 'ok - valid production configuration\n'

MARIADB_PASSWORD=ambient-override \
  "${PRODUCTION_DIR}/compose.sh" --env-file "${BASE_ENV}" config --format json \
  > "${FIXTURE_DIR}/compose.json"
if grep -Fq ambient-override "${FIXTURE_DIR}/compose.json"; then
  printf 'Ambient shell values overrode the validated environment file.\n' >&2
  exit 1
fi
printf 'ok - ambient Compose overrides are ignored\n'
python3 -B "${SCRIPT_DIR}/compose_contract_test.py" "${FIXTURE_DIR}/compose.json"

grep -Fq 'resolver 127.0.0.11' "${PRODUCTION_DIR}/proxy-nginx.conf.template"
grep -Fq 'proxy_pass http://$api_upstream/readiness' "${PRODUCTION_DIR}/proxy-nginx.conf.template"
grep -Fq 'proxy_pass http://$web_upstream' "${PRODUCTION_DIR}/proxy-nginx.conf.template"
printf 'ok - proxy refreshes service discovery\n'

grep -Fq 'helper_exec_path' "${PRODUCTION_DIR}/docker-socket-proxy.cfg"
grep -Fq '__PROJECT_NAME__-texlive-' "${PRODUCTION_DIR}/docker-socket-proxy.cfg"
grep -Fq 'http-request deny deny_status 403' "${PRODUCTION_DIR}/docker-socket-proxy.cfg"
printf 'ok - Docker API policy is default-deny and helper-scoped\n'

grep -Fq -- '--wait-timeout' "${PRODUCTION_DIR}/deploy.sh"
printf 'ok - deployment wait is bounded\n'

expect_failure placeholder-secret DF_SECRET_KEY_BASE REPLACE_ME "placeholder value"
expect_failure inline-comment-padding DF_SECRET_KEY_BASE 'x # padding-padding-padding-padding' "inline comments are not allowed"
expect_failure compose-interpolation DF_SMTP_PASSWORD 'unsafe$value' "contains a dollar sign"
expect_failure mutable-image DOUBTFIRE_WEB_IMAGE lmsdoubtfire/doubtfire-web:latest "immutable sha256 image digest"
expect_failure development-auth DF_AUTH_METHOD database "development-only"
expect_failure invalid-processor-memory TEXLIVE_MEMORY_LIMIT unlimited "positive whole number"
expect_failure unsupported-overseer OVERSEER_ENABLED 1 "must remain disabled"

insecure_env="${FIXTURE_DIR}/insecure-mode.env"
cp "${BASE_ENV}" "${insecure_env}"
chmod 644 "${insecure_env}"
if output="$("${PRODUCTION_DIR}/validate.sh" "${insecure_env}" 2>&1)"; then
  printf 'Expected insecure environment mode to fail.\n' >&2
  exit 1
fi
printf '%s' "${output}" | grep -Fq 'must not be accessible by group or other users'
printf 'ok - insecure environment permissions\n'

expect_failure non-local-daemon DOCKER_SOCKET_PATH "${FIXTURE_DIR}/docker.sock" "must be /var/run/docker.sock"

if [[ ! -S /var/run/docker.sock || ! -r /var/run/docker.sock || ! -w /var/run/docker.sock ]]; then
  if output="$(DOUBTFIRE_CONFIG_ONLY=0 "${PRODUCTION_DIR}/validate.sh" "${BASE_ENV}" 2>&1)"; then
    printf 'Expected an inaccessible Docker socket to fail.\n' >&2
    exit 1
  fi
  printf '%s' "${output}" | grep -Fq 'not an accessible Unix socket'
  printf 'ok - Docker socket preflight is fail-closed\n'
else
  printf 'ok - live Docker socket is accessible\n'
fi

mismatch_key="${FIXTURE_DIR}/mismatch.key"
openssl genpkey -algorithm RSA -out "${mismatch_key}" >/dev/null 2>&1
chmod 600 "${mismatch_key}"
expect_failure mismatched-tls TLS_PRIVATE_KEY_PATH "${mismatch_key}" "do not match"

printf 'All production validation tests passed.\n'
