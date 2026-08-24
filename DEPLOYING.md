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
- `curl`, OpenSSL, and standard GNU utilities including `timeout`;
- DNS for the production hostname and a trusted TLS certificate;
- an external AAF, SAML, or LDAP identity provider;
- an SMTP service and an operational sender address;
- outbound HTTPS access to the push services used by supported browsers;
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

### SCORM credential-path mitigation

The inherited SCORM content route is
`/api/scorm/:task_def_id/:username/:auth_token/*file_path`. Its `auth_token`
segment is a reusable credential until the corresponding SCORM token expires.
Putting a credential in a URL path can expose it through access and error logs,
browser history, copied links, monitoring and analytics systems, upstream edge
services, and referrer headers.

For this release, the included Nginx proxy suppresses access-log entries for
`/api/scorm/` paths and returns `Referrer-Policy: no-referrer` on those responses.
The rule is applied without a separate location block, so SCORM requests retain
the common API routing, forwarding headers, and timeout. These controls are
mitigation, not closure: they do not remove the credential from browser history,
the API request target, error reporting, an external load balancer, CDN, WAF, or
APM instrumentation. Configure equivalent redaction or suppression on every
component in front of or observing Doubtfire, restrict access to historic logs,
and treat any previously logged SCORM token as exposed until it expires or is
revoked.

The SCORM launch flow must be redesigned so reusable credentials are carried in
a Secure, HttpOnly, appropriately scoped SameSite cookie or an authorisation
header. Where SCORM clients cannot supply either, exchange a single-use,
short-lived launch code for scoped session state and keep usernames and tokens
out of subsequent asset URLs. That application redesign and token migration is
required before this risk can be considered closed.

During production acceptance, use a disposable SCORM test token and confirm its
asset responses include `Referrer-Policy: no-referrer`, no `/api/scorm/` request
appears in the proxy access log, and an ordinary API request is still logged.
Also inspect API, platform-edge, observability, and error-reporting destinations
for the disposable token, then revoke it. Never paste a real SCORM URL into a
ticket, chat, command history, or acceptance record.

## 1. Prepare runtime configuration

From the repository root:

```bash
cd production
cp .env.production.example .env.production
chmod 600 .env.production
```

Replace every `REPLACE_ME` value. The validator rejects placeholder values,
development database authentication, weak/short critical secrets, mutable image
tags, unsafe peer-progress settings, malformed or development VAPID keys,
missing processor limits, unsupported Overseer activation, and runtime files
with unsafe permissions.

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
LTI, and Gotenberg are not enabled by this stack. Peer Progress and Web Push are
enabled only through the explicit, fail-closed settings below.

### Sidekiq concurrency contract

Start with `DF_SIDEKIQ_CONCURRENCY=5`. Production validation permits only an
integer from 2 through 5, and Compose injects it only into Sidekiq. Five is the
upper bound of the default Active Record connection pool, which ensures each
worker thread can obtain a database connection without silently overcommitting
the pool. The lower bound keeps one long-running document or similarity job from
being the worker's only available execution path while notification and Peer
Progress jobs are queued.

This range is a release safety bound, not a capacity guarantee. Monitor queue
latency, retry/dead-job counts, database connection saturation, CPU, memory, and
the external PDF/JPlag helpers before lowering concurrency or planning a larger
worker topology. Raising it above 5 requires a coordinated application change,
an explicitly larger Active Record pool, and database-capacity testing; changing
only the environment file is deliberately rejected. Use API and app-worker
images from the same tested release so their concurrency validation, database
pool assumptions, job classes, and cron schedule remain compatible.

### Peer Progress privacy contract

Keep `DF_PPI_MINIMUM_COHORT_SIZE=21`, or raise it if the institution approves a
stricter privacy threshold. Values below 21 are rejected. Keep
`DF_PPI_STALE_AFTER_HOURS=48`, or lower it for a stricter freshness window;
zero, negative, non-integer, and values above 48 are rejected. The API also
fails closed rather than returning peer percentages if either setting is
missing or invalid.

Configuration does not opt units in. `units.peer_progress_enabled` defaults to
false and an authorised convenor must explicitly enable Peer Progress for each
approved unit. Start with a populated test unit, confirm the cohort policy with
the responsible privacy owner, and complete the activation and verification
steps in section 5 before enabling more units. Do not run demo seed tasks against
production.

### Web Push VAPID contract

Generate a new P-256 VAPID pair for this production installation using the
matching API release on a trusted administration host:

```bash
bundle exec ruby -e \
  "require 'web_push'; key = WebPush.generate_key; puts key.public_key; puts key.private_key"
```

Set `DOUBTFIRE_VAPID_PUBLIC_KEY`, `DOUBTFIRE_VAPID_PRIVATE_KEY`, and an explicit
`DOUBTFIRE_VAPID_SUBJECT`. The subject must be an operational `mailto:` address
or HTTPS contact URL. The example values are deliberately non-secret
placeholders and validation will reject them. The checked-in development pair
is also rejected. The private key is supplied only to the API and Sidekiq
containers; never put it in Git, tickets, build logs, or browser configuration.

Store the private key in the institution's secret manager and encrypted recovery
escrow alongside the Rails encryption keys. Preserve it across deployments and
restores. Rotating the pair invalidates every existing browser subscription:
schedule the rotation, deploy both API and Sidekiq with the new pair, notify
users, and require them to enable push again. A database restore without the
matching VAPID private key cannot deliver to its saved subscriptions.

Allow outbound TCP 443 from API and Sidekiq to the endpoint hosts issued by the
supported browsers. The current application allowlist includes
`fcm.googleapis.com`, `android.googleapis.com`,
`updates.push.services.mozilla.com`, `web.push.apple.com`, subdomains of
`push.services.microsoft.com`, and subdomains of `notify.windows.com`. Review
captured subscription endpoint hosts whenever the supported browser matrix
changes; do not assume browser vendors will keep endpoints static.

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
./verify.sh
```

The default health wait is five minutes. Supply a different bounded value in
seconds as the second argument when an approved migration needs longer:

```bash
./deploy.sh .env.production 900
```

The deployment helper validates configuration, pulls the exact image digests,
applies the stack, waits for declared health checks and running worker processes,
and prints diagnostics on a failed or timed-out rollout. `verify.sh` then runs
the fail-closed post-deploy gates against the same environment file and local
Compose wrapper. A one-shot `migrate` service runs after MariaDB is healthy; API
and worker startup is gated on successful migrations. API readiness checks both
MariaDB and Redis. Only ports 80 and 443 are published. MariaDB, Redis, the
Docker API proxy, and application services remain on private Compose networks.

Both helpers accept an explicit environment file. `verify.sh` also accepts a
bounded per-check timeout:

```bash
./verify.sh .env.production 60
```

It verifies public TLS/proxy readiness, direct API database/Redis readiness,
the web index and PWA control files, pending migrations, a live Sidekiq process
at the configured concurrency, the required peer-progress and notification cron
jobs, and live PPI/VAPID configuration without printing credentials or student
data. A successful exit means only that the automated gates passed; its clearly
labelled manual gates remain mandatory before traffic or a rollback is accepted.

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

Run the automated gate at minimum:

```bash
./compose.sh ps
./verify.sh
```

Complete every `MANUAL-*` gate printed by `verify.sh`. In particular, exercise a
real login through the configured identity provider, send a notification email,
generate a PDF through Sidekiq/TexLive, and run a permitted JPlag check before
accepting traffic. Confirm that database and Redis ports are not published and
that container logs contain no credentials or private keys.

For Peer Progress, have an authorised convenor enable it in Unit Settings for a
single approved test unit. Enqueue the first aggregation rather than waiting for
the nightly schedule (replace `UNIT_CODE` with the exact production unit code):

```bash
./compose.sh exec apiserver bundle exec rails runner \
  'unit = Unit.find_by!(code: "UNIT_CODE"); abort "Peer Progress is not enabled" unless unit.peer_progress_enabled?; AggregatePeerProgressJob.perform_async(unit.id); puts "Peer Progress aggregation queued"'
```

Wait for Sidekiq to log completion, then verify that the schedule is loaded and
that a fresh snapshot exists without printing student-level data:

```bash
./compose.sh exec sidekiq bundle exec rails runner \
  'abort "Peer Progress schedule missing" unless Sidekiq::Cron::Job.find("aggregate_peer_progress"); puts "Peer Progress schedule loaded"'
./compose.sh exec apiserver bundle exec rails runner \
  'unit = Unit.find_by!(code: "UNIT_CODE"); calculated_at = unit.peer_progress_snapshots.maximum(:calculated_at); abort "No Peer Progress snapshot" unless calculated_at; abort "Peer Progress snapshot is stale" if calculated_at < ENV.fetch("DF_PPI_STALE_AFTER_HOURS").to_i.hours.ago; puts "Fresh Peer Progress snapshot present"'
```

Sign in as a student in that test unit and inspect the Peer Progress response and
display. Confirm that an eligible cohort shows only the approved percentage and
state fields, while a cohort below the configured threshold (which can never be
lower than 21) is suppressed and never exposes names, identifiers, peer project
records, marks, raw statuses, or raw cohort counts.

Web Push acceptance requires a real supported browser and cannot be replaced by
Compose health checks. Over HTTPS, sign in and confirm `/ngsw.json` loads and the
authenticated `/api/settings` response reports `pushEnabled: true` with the
configured public key. Use the application's user-gesture control to grant
notification permission and create a subscription. Trigger a known notification
that is processed by Sidekiq, verify it appears with the application in the
background, and verify clicking it opens the intended OnTrack route. Record the
browser, operating system, endpoint host, and result. Repeat on at least one
desktop browser and every mobile/browser combination the institution promises
to support; iOS/iPadOS testing must use an installed Home Screen web app.

Monitor at least:

- external HTTPS and `/healthz` availability;
- container health/restarts and migration failures;
- Sidekiq queue latency, retries, and dead jobs;
- Peer Progress aggregation age and suppressed/error responses;
- scheduled PDF/JPlag job failures;
- Web Push delivery failures, expired subscriptions, and rejected endpoint hosts;
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
5. run `./validate.sh`, `./deploy.sh`, and `./verify.sh`, then complete the
   printed manual gates.

Afterward, repeat the verification checks and inspect worker queues and logs.
For an application rollback, restore the previous image digests, redeploy, run
`./verify.sh`, and repeat every applicable manual gate before accepting the
rollback. If a migration is not backward-compatible, image rollback alone is
unsafe; follow the migration's documented rollback or restore the matching
database and student-work recovery set in a controlled outage, then run the
same automated and manual acceptance gates.

Never run `./compose.sh down --volumes` against production. The temporary
TexLive and JPlag volumes are disposable, but the host paths configured for the
database, Redis, logs, and student work are production data.

## CI-only configuration rendering

`DOUBTFIRE_CONFIG_ONLY=1 ./validate.sh /path/to/fixture.env` skips only the live
Docker socket accessibility check. It exists for isolated CI validation and
must not be used by `deploy.sh` or as a production preflight substitute.
