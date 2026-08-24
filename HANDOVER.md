# OnTrack 11.0.x release handover

This is the authoritative handover checklist for the combined CPD, Peer
Progress Indicator (PPI), Email Notifications, Mobile/Web Push Notifications,
and retained demonstration package. `DEPLOYING.md` is the detailed production
runbook; `development/all-features-demo/README.md` is the disposable demo
runbook. Older integration and PR-tracker documents are historical evidence and
must not override this file or the pinned component revisions below.

The package is deployment-ready when every automated and manual gate in this
document is complete. It is not a preconfigured live service: the receiving
institution must supply and own its identity-provider, SMTP, TLS, registry,
secrets, storage, monitoring, backup, privacy, and browser/device acceptance.

## Release contents

| Component | Release branch | Pinned revision |
| --- | --- | --- |
| Deploy and handover | `integration/deploy-all-features-foundation-20260824` | Protected signed release tag; record the resolved commit externally |
| API and Sidekiq | `integration/11.0.x-all-features-20260824` | `5f7ccc7c8f8dc9715d45e3607b7365c47237ac7e` |
| Web application | `integration/11.0.x-all-features-20260824` | `4d0d994b0bc9cd516ba85855972812a1b5764d9a` |

A Git commit cannot contain its own final hash. After the accepted deploy commit
is tagged under the protected release policy, resolve that signed tag to a
commit and record it in the external release manifest; the release publisher
also emits it. The API and web revisions, by contrast, must be pinned in this
file and by the `doubtfire-api` and `doubtfire-web` gitlinks in the accepted
deploy commit. Build both the API and app-worker images from the same API
revision. Build the web image from the exact web revision. Publish them to an
institution-controlled registry and deploy only immutable `image@sha256:...`
references. Do not deploy an arbitrary branch tip or a mutable tag such as
`latest` or `11.0.x`.

The umbrella pull requests intentionally preserve the complete reviewed feature
history and the guarded demos. Repository review rules and required human
approvals still apply; deployment readiness does not bypass them.

Create protected signed release refs in the API and web repositories that point
to their pinned commits, and record those refs with the deploy release tag. A
mutable integration branch is review evidence, not long-term source retention.
The release is blocked until a genuinely fresh recursive clone can fetch all
three retained revisions from the configured repository URLs.

## Supported production and demo boundaries

Production includes the live CPD, PPI, email, push, scheduled-work, PDF, and
JPlag paths wired by `production/docker-compose.yml`. Production deliberately:

- rejects database authentication, placeholder or development secrets, mutable
  images, unsafe PPI settings, malformed VAPID settings, and missing resource
  limits for the Docker-invoked TexLive/JPlag helpers;
- serves the web demo controls disabled and does not run Mailpit or demo seed
  tasks;
- requires an externally managed AAF, SAML, or LDAP identity provider and SMTP
  service; and
- exposes only HTTPS/HTTP through the proxy; MariaDB, Redis, Sidekiq, API, and
  the Docker socket proxy remain private.

The retained all-features demo is isolated under
`development/all-features-demo/`. It uses a dedicated Compose project,
database, containers, volume, Mailpit, synthetic accounts, guarded seed data,
and visible demo controls. It may be run from complete sibling API/web checkouts
or the pinned submodules. Demo usernames, the shared development password,
Mailpit, synthetic PPI data, push preview behaviour, and `DF_DEMO_DATA_PROFILE`
are never production configuration.

Some demonstration views intentionally use labelled synthetic data where no
equivalent production API exists. PPI compact completion and advanced status
percentages in production are live aggregates. They fail closed below the
configured remaining-peer cohort after excluding the reader, and the advanced
vector has an additional ambiguity guard. Legacy or viewer-stale snapshots also
fail closed until reaggregation. Treat the demo as a walkthrough and test
fixture, not as production acceptance evidence.

## Receiving-team ownership

Assign a named owner and a deputy before the change window. Empty ownership is a
release blocker.

| Responsibility | Required owner |
| --- | --- |
| Change approval, release manifest, go/no-go, rollback decision | Release owner |
| Host, registry, DNS, TLS, secrets, storage, monitoring, backups | Platform operations |
| AAF/SAML/LDAP metadata, claims, logout, emergency access | Identity owner |
| SMTP relay, sender policy, bounce/failure monitoring | Messaging owner |
| PPI cohort policy, approved units, privacy acceptance | Privacy/data owner |
| CPD, PPI, email and push workflow acceptance | Product owner |
| Desktop/mobile browser support and service-worker acceptance | Client support owner |

Store the completed checklist and evidence in the institution's change record,
not in Git. Evidence must not contain credentials, student data, SCORM launch
URLs, auth fragments, VAPID private keys, or Rails encryption keys.

## Release manifest

Record this before deployment and again after any rollback:

```text
Change record:
Release owner / deputy:
Maintenance window and timezone:
Approved release version:
Deploy Git revision:
Deploy signed release ref:
API Git revision: 5f7ccc7c8f8dc9715d45e3607b7365c47237ac7e
API signed release ref:
Web Git revision: 4d0d994b0bc9cd516ba85855972812a1b5764d9a
Web signed release ref:
Release-ref signature verification evidence:
API image digest:
App-worker image digest:
Web image digest:
Proxy / MariaDB / Redis / HAProxy image digests:
TexLive / JPlag image digests:
SBOM / provenance / signature / vulnerability-scan evidence:
Previous release manifest:
Source release / schema version:
Database migration version:
Backup and isolated restore-test references:
Approved RPO / RTO / retention / restore-test cadence:
Secret-manager and recovery-escrow version references:
TLS certificate expiry:
VAPID public-key fingerprint (never the private key):
Automated verification evidence:
Manual acceptance evidence:
Known-risk approvals:
Go/no-go and rollback decision:
```

The organisation that owns the production registry also owns revision-locked image
publication, vulnerability scanning, digest retention, and provenance. The team
repository workflows may validate source changes, but they are not a substitute
for an authorised institutional image-publishing process.

## Pre-deployment gate

- [ ] Required pull requests have human approval and green required checks.
- [ ] Default/release rulesets prevent deletion and non-fast-forward changes,
      require pull requests, require `ontrack-leads` approval (through CODEOWNER
      review or an equivalent required-reviewer rule), and make the relevant
      API/web/deploy validation checks mandatory rather than merely advisory.
- [ ] Protected tag rules prevent the signed deploy/API/web release refs from
      being moved or deleted after their signatures are verified.
- [ ] The API/web gitlinks match the release table and are reachable from the
      protected signed component release refs; a fresh recursive clone has
      fetched them from the configured submodule URLs.
- [ ] API and app-worker images came from the same API revision; the web image
      came from the pinned web revision; all configured images use digests.
- [ ] Every application/helper/base digest has accepted SBOM, provenance,
      vulnerability/licence scan and signature-verification evidence; any risk
      acceptance has a named owner and expiry.
- [ ] Production `.env.production` was created from the example, has mode 0600,
      is stored outside version control, and passes `production/validate.sh`.
- [ ] Independent Rails, database, SMTP, identity-provider and VAPID secrets are
      held in the approved secret manager and recovery escrow.
- [ ] The identity owner has revoked the AAF shared credential previously
      committed to this repository's history and confirmed it is not reused;
      removing it from the current tree does not make the exposed value safe.
- [ ] Existing Rails signing/encryption and VAPID keys are retained unless an
      approved rotation plan explicitly handles their impact.
- [ ] DNS, trusted TLS, outbound push endpoints, SMTP, persistent paths, disk
      capacity, processor limits, alerts, on-call routing and certificate
      renewal are ready.
- [ ] A recent database plus complete student-work backup has been restored in
      an isolated environment and application checks passed.
- [ ] RPO, RTO, backup frequency/retention, off-host copy, restore-test cadence,
      secret escrow and the Redis/queued-job loss decision are approved.
- [ ] Migration compatibility and the previous manifest have been reviewed;
      the rollback owner knows whether image rollback alone is safe and has a
      rehearsed, bounded API-before-web procedure plus a release-matched
      acceptance procedure.
- [ ] For an existing installation, the exact source release/schema is recorded
      and its production-sized isolated migration rehearsal passed; an unknown
      or drifted source schema is a release blocker.
- [ ] The SCORM credential-in-path residual risk and every upstream logging,
      CDN/WAF/APM redaction control have written acceptance. See
      `DEPLOYING.md` for the disposable-token verification procedure.

Run the production preflight from `production/`:

```bash
./validate.sh
```

Do not waive a failed validator. Fix the configuration or release input and run
it again.

## Deployment and first installation

Follow `DEPLOYING.md` for the complete procedure. The release sequence is:

```bash
cd production
./validate.sh
./deploy.sh
./verify.sh
```

`deploy.sh` pulls exact digests and first stages a healthy hardened web image
that understands both old query and new fragment callbacks. It then updates the
API/workers, runs migrations once, and gates application and worker startup on
migration success. Do not reverse that forward order: API-first can interrupt
SSO while an old web instance is still served. `verify.sh` checks
public health and PWA control files, direct database/Redis readiness, pending
migrations, Sidekiq registration/concurrency/cron schedules, and the live
PPI/VAPID contract. Save its output after redacting only operational hostnames
if policy requires it; never modify it to turn a failed gate into a pass.

For a new empty database only, keep public ingress blocked and run `db:init` once
as documented in `DEPLOYING.md`. It creates the application roles/statuses and an
`aadmin` record.
With required external authentication it does not create a database password.
Before accepting traffic, an authorised operator must update that one record's
`login_id`, `username`, email, and profile to the exact approved IdP identity,
confirm it retains the Admin role, complete a real IdP login, and record the
change. Do not create or retain a shared local administrator password. Existing
installations must not rerun initialisation as a substitute for migration.

## Mandatory manual acceptance

An automated green result is necessary but not sufficient. Complete every
`MANUAL-*` line printed by `verify.sh`, plus this checklist:

- [ ] Sign in and sign out through the production AAF/SAML/LDAP provider with
      the mapped administrator and an ordinary test user; verify fragments are
      scrubbed from the visible URL before telemetry starts.
- [ ] Keep LTI disabled unless its separately deployed redirector is proven to
      return credentials through a URL fragment, POST, or secure cookie rather
      than a query string. If enabled, verify the first edge request contains no
      `ltik`, `ltiToken`, auth token, or username credential parameter.
- [ ] Exercise representative CPD cross-unit recommendations and confirm a user
      cannot retrieve task definitions or recommendation data outside their
      authorised units.
- [ ] Enable PPI only for one privacy-approved test unit, queue the first
      aggregation, and verify snapshot freshness. Check the compact and advanced
      indicator below the submission area, representative redo/resubmit states,
      the default-on profile preference and its off switch, eligible output,
      remaining-peer sub-threshold suppression, legacy/viewer-stale snapshot
      suppression, and advanced-vector suppression without identifiers, cohort
      size, or raw counts.
- [ ] Trigger immediate and scheduled email paths through Sidekiq; verify the
      approved sender, links, SMTP delivery, failure alerting, and no duplicate
      delivery on retry.
- [ ] On HTTPS, subscribe and receive a background push on every promised
      desktop/mobile/browser combination. Include an installed Home Screen app
      for supported iOS/iPadOS. Verify click-through and expired-subscription
      cleanup.
- [ ] Generate a representative PDF and permitted JPlag result; verify the
      constrained Docker proxy and host resource ceilings.
- [ ] Run the disposable SCORM-token log/referrer test across proxy, platform
      edge and observability systems, then revoke it.
- [ ] Confirm no database, Redis, API, worker, or Docker-proxy port is public;
      inspect logs and telemetry for credentials, private keys and student data.
- [ ] Confirm external health, queue latency/retries/dead jobs, PPI snapshot age,
      SMTP/push failures, storage/backup age, TLS expiry and container restarts
      reach the named on-call owner.
- [ ] Re-run `./verify.sh`; attach results and obtain release-owner go/no-go.

## Known residual risks

- The inherited SCORM route carries a reusable token in its path. This release
  suppresses matching proxy access logs, applies `Referrer-Policy: no-referrer`,
  and redacts the bundled client's Sentry URL/breadcrumb telemetry while browser
  tracing and replay remain disabled. External edge/APM/error telemetry still
  requires explicit acceptance, and the application protocol requires the
  redesign described in `DEPLOYING.md`.
- Push acceptance depends on real vendor endpoints, browser permission, HTTPS,
  operating-system policy and device state, so it cannot be proven in CI.
- IdP, SMTP, institutional edge, monitoring, backup/restore and support-device
  behaviour are external responsibilities and remain manual release gates.
- This is a hardened single-host Compose deployment, not a high-availability
  topology. The receiving team owns capacity, outage objectives and any future
  multi-host design.

## Rollback and recovery

Stop the rollout on any failed automated or manual gate. Preserve diagnostics,
do not run `docker compose down --volumes`, and use the previous release
manifest. If migrations are backward-compatible, restore the previous immutable
digests during a maintenance/drain window. Roll back the API before the web so
the hardened web continues to accept either callback form; do not use the
forward web-first helper against a still-hardened API unless traffic is blocked.
Use the automated verifier and acceptance procedure recorded with the previous
release manifest, then repeat the release-independent manual gates. The current
`verify.sh` is deliberately tied to this release's exact schema, jobs and feature
contract and must not be weakened or presented as a valid green result for older
images. If the previous release has no compatible automated verifier, record a
named `MANUAL-ROLLBACK-CONTRACT` gate and directly prove public and dependency
readiness, migrations, queues, identity, messaging, data integrity and port/log
controls before accepting it. If a migration is not backward-compatible, image
rollback alone is unsafe: perform the reviewed migration rollback or restore the
matching database and student-work recovery set during a controlled outage.

A rollback is complete only after service verification, queue inspection,
identity/email checks, data-integrity checks, monitoring recovery, and a named
owner's acceptance. Rotate any secret shown in logs or evidence.

## Retained demo handover

The demo remains part of the repository and is independently disposable. From
a fresh recursive clone, or from sibling API/web checkouts at the pinned
revisions:

```bash
development/all-features-demo/demo.sh config
development/all-features-demo/demo.sh sources
development/all-features-demo/demo.sh prepare
development/all-features-demo/demo.sh verify
development/all-features-demo/demo.sh status
```

Follow `development/all-features-demo/README.md` for the walkthrough, source
override variables, test accounts, Mailpit and cleanup. To remove only the demo
project and its demo volume, use its guarded `destroy` command exactly as
documented. Never point the demo at a production database, never set its guard
variables in production, and never treat its synthetic output as acceptance
evidence.
