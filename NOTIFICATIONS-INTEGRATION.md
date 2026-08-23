# Notifications integration environment

This directory is the combined Email Notifications (EN) and Mobile
Notifications (MN) environment. It deliberately uses dedicated sibling
worktrees so the primary API and web repositories can remain on their unrelated
feature branches.

## Included code

The integration is based on the current `11.0.x` mainline plus the complete
`feature/notifications` foundation.

### Web

- PR #69 — MN-W03 reliable PWA install prompt
- PR #70 — MN-W04 persistent update/recovery prompt
- PR #71 — MN-C05 re-subscribe after browser push-registration rotation

### API

- PR #43 — EN-F03 queued notification email delivery
- PR #47 — EN-V04 tutorial-change notification
- PR #48 — EN-V06 tutor notification when work is submitted for marking
- PR #49 — EN-V07 portfolio submission receipt
- PR #50 — EN-V08 discussion-request proposal
- PR #51 — MN-S04 privacy-safe v2 lock-screen wording
- PR #52 — EN-T03 notification preference coverage
- EN-D06, MN-D02, MN-D04, and MN-D05 branch-only documentation
- MN-Q01 and MN-Q02 verification records, retained as blocked records rather
  than represented as passed device verification

PR #50 does not implement a real booking event. OnTrack has no discussion
booking record, so the proposal raises `discussion_request_created` when a tutor
sends an audio discussion prompt. Product approval is required before presenting
this as the final EN-V08 interpretation.

### Deployment

- PR #10 — local Sidekiq worker required by API PR #43
- Mailpit, Redis, development VAPID keys, API, worker, web, and MariaDB
- Notification-specific Docker image tags to prevent another OnTrack worktree
  from replacing the API or web image during a demo
- User-facing email links point to the web app at `http://localhost:4400`

## Repository layout

```text
notifications-environment/
  doubtfire-api/     integration/notifications-all-20260823
  doubtfire-web/     integration/notifications-all-20260823
  doubtfire-deploy/  integration/notifications-environment-20260823
```

The Compose local-path overlay expects this exact sibling layout.

## Start the isolated local environment

The local-path overlay gives this stack dedicated container names, image tags,
volumes, and host ports, so it can run alongside another OnTrack or PPI
worktree. Start it under the `notifications-demo` project name.

From this repository's `development` directory:

```bash
cd /Users/ryan/Downloads/test-codex/notifications-environment/doubtfire-deploy/development

# Validate the resolved configuration.
docker compose -p notifications-demo \
  -f docker-compose.yml \
  -f docker-compose.local-paths.yml \
  config --quiet

# Start the combined stack. Build again after changing API/web revisions.
docker compose -p notifications-demo \
  -f docker-compose.yml \
  -f docker-compose.local-paths.yml \
  up -d --build

# Populate a fresh demo database once.
docker compose -p notifications-demo \
  -f docker-compose.yml \
  -f docker-compose.local-paths.yml \
  run --rm doubtfire-api \
  bash -c "bundle exec rake db:populate"

# Check services, push prerequisites, and the real asynchronous email path.
bash verify-notifications.sh
```

Do not use `down -v` unless the demo database can be discarded. The `-v` flag
deletes the named database, Redis, and web dependency volumes.

## Local URLs and accounts

- OnTrack: <http://localhost:4400>
- API documentation: <http://localhost:3200/api/docs>
- Mailpit: <http://localhost:8225>

All seeded users use password `password`:

- Student: `student_1`
- Tutor: `atutor`
- Convenor: `aconvenor`
- Admin: `aadmin`

Use persistent, separate browser profiles for the actor and notification
recipient; private windows are unsuitable for a recipient that needs a durable
push subscription. The verifier temporarily posts one synthetic task comment,
waits for its notification email, then removes the comment and matching in-app
notification. Run it before staging the recording data, then clear Mailpit.

## Verification

The focused API tests use a separate database named
`doubtfire-notifications-test`; do not point tests at the recording database.
The combined async-email integration requires the event tests to drain
`NotificationEmailJob` before inspecting rendered mail.

Populate the test database once before the first API test run:

```bash
docker compose -p notifications-demo \
  -f docker-compose.yml \
  -f docker-compose.local-paths.yml \
  run --rm -e RAILS_ENV=test doubtfire-api \
  bash -c "bundle exec rake db:populate"
```

For web verification, run the notification, PWA prompt, service-worker update,
and application component specs, then build the production/service-worker
bundle. A service worker is required for actual Web Push and PWA footage.

`verify-notifications.sh` confirms that push configuration and service-worker
files are present; it does not prove that an OS/browser push was delivered. MN-Q01
and MN-Q02 require fresh browser and Android evidence before compatibility can be
claimed.

## Prepare the PWA update-prompt shot

The normal app runs at port 4400. The update shot needs two immutable builds at
one origin, so it has a dedicated, optional helper on port 4500:

```bash
cd /Users/ryan/Downloads/test-codex/notifications-environment/doubtfire-deploy/development

# Build A and B, serve A, and add a visible demo-only build marker.
./prepare-pwa-update-demo.sh prepare

# With the A tab still open at http://localhost:4500, switch the server to B.
./prepare-pwa-update-demo.sh b

# Return to A for another take, or stop the optional static server.
./prepare-pwa-update-demo.sh a
./prepare-pwa-update-demo.sh stop
```

After switching to B, reload the controlled A tab once and wait about 10 seconds
for the app's service-worker check. Record the persistent **Reload** action, then
click it and show the marker change from A to B. Keep these preparation commands
off camera.

## Hosted deployment blockers

The local recording environment is self-contained. The checked-in production
stack is not safe to publish as-is:

- production image references are still old and must be replaced with images
  built from the exact integration revisions;
- SMTP credentials and an SMTP-authorised `DF_INSTITUTION_EMAIL_SENDER` value
  are not configured;
- production VAPID public/private keys and subject are not configured;
- HTTPS is mandatory for hosted PWA/Web Push use;
- notification migrations must run before traffic reaches the new API;
- API and Sidekiq must use the same revision;
- `TZ` must match the institution so the 8am due-soon schedule runs at the
  intended local time;
- the production database needs a backup and migration rehearsal.

Build and tag the web, API, and appserver/Sidekiq artifacts from this integration,
configure SMTP plus the sender address, create production VAPID keys, migrate
the database, start the worker, then deploy API and web. API and Sidekiq both
load the same production environment, including host, product, sender, SMTP,
VAPID, and time-zone settings. Do not reuse the checked-in development VAPID key
in a hosted environment.
