# Deploying Doubtfire

The `production` directory is a fail-closed, single-host Docker Compose
deployment for the core Doubtfire application. It runs the web and API services,
MariaDB, Redis/Sidekiq, scheduled work, PDF generation, and JPlag behind HTTPS.

It does not contain credentials, institution settings, TLS private keys, or a
default image release. Those values are deployment-specific and must be supplied
before validation will pass. LTI and Gotenberg are optional integrations with
separate component contracts and are not enabled by this stack.

## Requirements and trust boundary

Use a dedicated Linux host with:

- Docker Engine and Docker Compose v2.33.1 or newer;
- DNS for the production hostname and a trusted TLS certificate;
- an external AAF, SAML, or LDAP identity provider;
- an SMTP service and an operational sender address;
- persistent storage for MariaDB, Redis, logs, and student work; and
- monitored, regularly restored backups of the database and student work.

The PDF and JPlag implementation invokes existing helper containers through the
Docker API. The included HAProxy policy allows only ping/version plus
inspect/exec requests for `jplag` and this project's two TexLive containers; all
other Docker API paths and methods are denied. The proxy is reachable only from
the worker network and is never published. Possession of a Docker socket is
still a high-trust boundary, so use a host dedicated to Doubtfire, pin the tested
HAProxy Alpine image, review policy changes, and monitor denials. The API expects
the JPlag container name `jplag`, so run only one production project per daemon.

## 1. Prepare runtime configuration

From the repository root:

```bash
cd production
cp .env.production.example .env.production
chmod 600 .env.production
```

Replace every `REPLACE_ME` value. The validator rejects placeholder values,
development database authentication, weak/short critical secrets, mutable image
tags, missing processor limits, unsupported Overseer activation, and runtime
files with unsafe permissions.

Keep each setting in canonical `KEY=value` form. Full-line comments are allowed,
but quoted or escaped values, inline comments, dollar-sign interpolation, and
leading or trailing whitespace are rejected so validation and Compose cannot
interpret the same file differently.

Generate independent random values for database and Rails secrets. For example:

```bash
openssl rand -hex 32
```

Generate a new value for each setting. Existing installations must retain their
Rails signing and Active Record encryption values; changing them without a
planned rotation can invalidate sessions or make encrypted data unreadable.

Set `DF_AUTH_METHOD` to `aaf`, `saml`, or `ldap` and complete that provider's
settings. `database` authentication is deliberately rejected for production.
Set institution, SMTP, and sender values to real operational endpoints. Overseer,
LTI, Gotenberg, and Web Push are not part of the target `11.0.x` core contract
and are not enabled by this stack.

## 2. Pin tested images

Every image setting must use an immutable digest:

```text
registry.example/image@sha256:64_hex_characters
```

Build or select mutually compatible API, app-worker, web, TexLive, and JPlag
images, then resolve the digest after publishing. For example:

```bash
docker buildx imagetools inspect lmsdoubtfire/doubtfire-web:RELEASE_TAG
```

Record the tested digest in `.env.production`, including for Nginx, MariaDB,
Redis, and `haproxy:3.2-alpine`. The app-worker image must include the secure
production runtime scripts from the matching Doubtfire API release; older
`pdfgen_entry_point.sh` versions print their environment and must not be used.
The API image must come from the same release and provide the dependency-aware
`/readiness` endpoint used by the Compose and public health checks.

## 3. Prepare host storage and service files

Create the absolute directories configured by `STUDENT_WORK_PATH`,
`DOUBTFIRE_LOG_PATH`, `MARIADB_DATA_PATH`, and `REDIS_DATA_PATH`. Also create
`JPLAG_REPORT_PATH` and `JPLAG_ARCHIVE_REPORT_PATH` beneath the student-work
directory. The JPlag container receives only those two report paths, and the
TexLive containers receive no student-work mount. Keep runtime data outside the
Git checkout and restrict ownership to the deployment operators and container
users that require access.

Set explicit CPU, memory, and PID ceilings for TexLive and JPlag based on host
capacity and measured workload. The supplied example is a conservative starting
point, not a sizing guarantee.

Provide the certificate and unencrypted private key configured by
`TLS_CERTIFICATE_PATH` and `TLS_PRIVATE_KEY_PATH`. The validator confirms that
the certificate matches the key and hostname and will remain valid for at least
30 days. Restrict the private key to its owner:

```bash
chmod 600 /absolute/path/to/private.key
```

Copy the mail helper examples outside the repository and replace every
placeholder:

```bash
sudo install -m 0644 shared-files/aliases.example /etc/doubtfire/aliases
sudo install -m 0600 shared-files/msmtprc.example /etc/doubtfire/msmtprc
```

Update the two absolute paths in `.env.production`. The Rails SMTP settings and
`msmtprc` should describe the same approved mail service.

Automate certificate renewal. Because the certificate and key are file bind
mounts, recreate only the proxy after a successful renewal so Docker remounts
the replacement files, then verify both public health endpoints:

```bash
./compose.sh up --detach --no-deps --force-recreate --wait --wait-timeout 60 proxy
```

## 4. Validate and deploy

Run the preflight before every deployment:

```bash
./validate.sh
```

Deploy only after it passes:

```bash
./deploy.sh
```

The default health wait is five minutes. Supply a different bounded value in
seconds as the second argument when an approved migration needs longer:

```bash
./deploy.sh .env.production 900
```

The helper validates configuration, pulls the exact image digests, applies the
stack, waits for declared health checks and running worker processes, and prints
diagnostics on a failed or timed-out rollout. A one-shot `migrate` service runs
after MariaDB is healthy; API and worker startup is gated on successful
migrations. API readiness checks both MariaDB and Redis. Only ports 80 and 443
are published. MariaDB, Redis, the Docker API proxy, and application services
remain on private Compose networks.

`compose.sh` deliberately clears the ambient shell before invoking Compose and
pins the Docker CLI to the local `/var/run/docker.sock`. This prevents exported
variables or a remote Docker context from changing the configuration that was
validated. The production host must expose its local Docker daemon at that
standard socket path.

On the first deployment, initialise Doubtfire's roles, statuses, and initial
administrator once:

```bash
./compose.sh exec apiserver bundle exec rake db:init
```

Then use the Rails console to replace the initial administrator's placeholder
profile with the authorised operational identity. Do not enable database
authentication or retain a default password to make first login easier.

## 5. Verify the deployment

At minimum, verify:

```bash
./compose.sh ps
curl --fail --silent --show-error https://ontrack.your-institution.edu.au/healthz
curl --fail --silent --show-error https://ontrack.your-institution.edu.au/healthz/web
./compose.sh exec apiserver bundle exec rails db:abort_if_pending_migrations
```

Also exercise a real login through the configured identity provider, send a
notification email, generate a PDF through Sidekiq/TexLive, and run a permitted
JPlag check before accepting traffic. Confirm that database and Redis ports are
not published and that container logs contain no credentials or private keys.

Monitor at least:

- external HTTPS and `/healthz` availability;
- container health/restarts and migration failures;
- Sidekiq queue latency, retries, and dead jobs;
- scheduled PDF/JPlag job failures;
- SMTP delivery failures;
- database/storage capacity and backup age; and
- TLS certificate expiry.

## Backups and restore tests

Back up the MariaDB database and the complete `STUDENT_WORK_PATH` as one recovery
set. A database dump can be streamed to protected host storage without writing
it into a container:

```bash
BACKUP_DIR=/srv/doubtfire/backups
sudo install -d -m 0700 "${BACKUP_DIR}"
umask 077
./compose.sh exec -T doubtfire-db sh -c \
  'exec mariadb-dump --single-transaction --routines --events \
    --user="$MARIADB_USER" --password="$MARIADB_PASSWORD" "$MARIADB_DATABASE"' \
  > "${BACKUP_DIR}/doubtfire-$(date -u +%Y%m%dT%H%M%SZ).sql"
```

Use filesystem or storage-provider snapshots for student work and database data
where available. Encrypt backups, restrict access, define retention, and keep a
copy outside the deployment host. A backup is not accepted until it has been
restored into an isolated environment and application-level checks pass.

## Upgrades and rollback

Before an upgrade:

1. confirm the backup and restore test are current;
2. record the running image digests and Git revision;
3. review API migrations for backward compatibility;
4. update only the tested digests in `.env.production`; and
5. run `./validate.sh` followed by `./deploy.sh`.

Afterward, repeat the verification checks and inspect worker queues and logs.
For an application rollback, restore the previous image digests and redeploy.
If a migration is not backward-compatible, image rollback alone is unsafe;
follow the migration's documented rollback or restore the matching database and
student-work recovery set in a controlled outage.

Never run `./compose.sh down --volumes` against production. The temporary
TexLive and JPlag volumes are disposable, but the host paths configured for the
database, Redis, logs, and student work are production data.

## CI-only configuration rendering

`DOUBTFIRE_CONFIG_ONLY=1 ./validate.sh /path/to/fixture.env` skips only the live
Docker socket accessibility check. It exists for isolated CI validation and
must not be used by `deploy.sh` or as a production preflight substitute.
