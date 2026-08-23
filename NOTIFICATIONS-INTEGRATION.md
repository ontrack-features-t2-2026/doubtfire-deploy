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
- User-facing email links point to the web app at `http://localhost:4200`

## Repository layout

```text
notifications-environment/
  doubtfire-api/     integration/notifications-all-20260823
  doubtfire-web/     integration/notifications-all-20260823
  doubtfire-deploy/  integration/notifications-environment-20260823
```

The Compose local-path overlay expects this exact sibling layout.

## Start the isolated local environment

The compose files use global container names and ports. Another OnTrack stack
cannot run at the same time. Remove the old stack without deleting its volumes,
then start this one under its own project name.

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

# Ensure all services and the basic email/push path are healthy.
bash verify-notifications.sh
```

Do not use `down -v` unless the demo database can be discarded. The `-v` flag
deletes the named database, Redis, and web dependency volumes.

## Local URLs and accounts

- OnTrack: <http://localhost:4200>
- API documentation: <http://localhost:3000/api/docs>
- Mailpit: <http://localhost:8025>

All seeded users use password `password`:

- Student: `student_1`
- Tutor: `atutor`
- Convenor: `aconvenor`
- Admin: `aadmin`

Use separate browser profiles for the actor and notification recipient. Clear
Mailpit before recording.

## Verification

The focused API tests use a separate database named
`doubtfire-notifications-test`; do not point tests at the recording database.
The combined async-email integration requires the event tests to drain
`NotificationEmailJob` before inspecting rendered mail.

For web verification, run the notification, PWA prompt, service-worker update,
and application component specs, then build the production/service-worker
bundle. A service worker is required for actual Web Push and PWA footage.

## Hosted deployment blockers

The local recording environment is self-contained. The checked-in production
stack is not safe to publish as-is:

- production image references are still old and must be replaced with images
  built from the exact integration revisions;
- SMTP credentials and a real sender address are not configured;
- production VAPID public/private keys and subject are not configured;
- HTTPS is mandatory for hosted PWA/Web Push use;
- notification migrations must run before traffic reaches the new API;
- API and Sidekiq must use the same revision;
- the production database needs a backup and migration rehearsal.

Build and tag the web, API, and appserver/Sidekiq artifacts from this integration,
configure the SMTP/VAPID/sender secrets outside Git, migrate the database, start
the worker, then deploy API and web. Do not reuse the checked-in development
VAPID key in a hosted environment.
