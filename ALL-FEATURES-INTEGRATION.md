# OnTrack 11.0.x all-features integration lock

This file records the local integration assembled on 24 August 2026. It is the
single local CPD, Peer Progress Indicator (PPI), Email Notifications (EN), and
Mobile Notifications (MN) stack. The companion operating instructions are in
`RUNNING-LOCALLY.md`. Review branches, dependencies, and merge order are
tracked in `ALL-FEATURES-PR-FOLLOWUPS.md`.

## Local branches and locked component revisions

Check out `integration/11.0.x-all-features-20260824` in all three sibling
repositories. The deploy repository's gitlinks lock the API and web inputs,
while the development Compose overlay runs those sibling working trees.

| Repository | Required local revision |
| --- | --- |
| `doubtfire-deploy` | This branch (`git rev-parse HEAD` gives the coordination revision) |
| `doubtfire-api` | `2f945c71203a47f8777ad158966a2cdff765109a` |
| `doubtfire-web` | `36be84f30d80c237e97a0f15b607ec0b1b3a4b57` |

These revisions were local when this validation lock was recorded. Their
publication and PR status is tracked in `ALL-FEATURES-PR-FOLLOWUPS.md`. A fresh
clone must not run `git submodule update` until both locked component commits
are reachable from published branches; until then, use the sibling checkouts
described in `RUNNING-LOCALLY.md`.

## Source snapshot

The final GitHub audit was refreshed at `2026-08-23T22:35:34Z` after
publication of the PPI lint prerequisite. It reported 21 open
API PRs, 27 open web PRs, and nine open deploy PRs. The original in-scope
inventory below was
unchanged; every exact PR
head remained an ancestor of its local integration branch, and every named
feature branch still matched the recorded SHA. No relevant PR was new,
rebased, stale, or missing at that checkpoint.

Base `11.0.x` revisions:

- deploy: `0c26967a5a76128f05b430553e6ed215d181487b`
- API: `e86de767d90fb851051087e0a56f949a55430ce1`
- web: `81b65f4d293a8da3cf2fa3aeb9af2f040b39de43`

Named feature heads included in the API:

- `feature/cross-unit`: `5064860967deca8fe61be774a42d913b4f95e66d`
- `feature/peer-progress-indicator`: `40d676ce1fcbf3abddd19559a7e392221f4bb7ba`
- `feature/notifications`: `cb1b031835b4905a1eec61820aacec6f2ae9a083`
- `feature/email-notifications`: `5850668ae8b1e05c38d6c99aeb4aa0c3ab5d866a`
- `feature/mobile-notifications`: `dc76a5a0e67ec4b751a5830c462c71b961eb60b1`

Named feature heads included in the web app:

- `feature/cross-unit`: `53f1c5532eefc75cadf7834748a5a85c2bc6b3e8`
- `feature/peer-progress-indicator`: `1e3b9f49a4166638caf31cd6086820c370336492`
- `feature/notifications`: `f5f31a8c429524b8a0be5211e0a057b94a55dc16`
- `feature/email-notifications`: `20d1f380c20fa6f6601eea1db6814a77401f391c`
- `feature/mobile-notifications`: `20d1f380c20fa6f6601eea1db6814a77401f391c`

The three named `feature/...` branches do not exist in the deploy repository.
Their deployment wiring is supplied by deploy PR #10, the retained local
notification/PPI integration commits, and this combined branch.

## Open PR inventory

Included because they are in the requested feature or integration scope:

- deploy: #10
- API: #41, #42, #43, #45, #46, #47, #48, #49, #50, #51, #52
- web: #57, #58, #59, #60, #61, #62, #69, #70, #71, #72, #73

Every exact PR head above is an ancestor of its local integration branch.

Open PRs deliberately excluded from the web branch are outside this scope:

- #52, #53, #64, and #68: calendar/ICS work
- #54: task-comment composer layout refactor
- #63: English-language submission documentation (not Email Notifications)
- #67: audio waveform UI

Deploy PR #9 is excluded. It only changes the Teams PR-notification workflow,
is outside application CPD/PPI/EN/MN behaviour, and was not security-approved.

## Local repairs retained for later PRs

Reviewer-ready API repairs extracted from the locked revision:

- `fix/cpd-task-definition-privacy-pr-20260824` at `8b2250b94`
- `style/ppi-sample-data-lint-pr-20260824` at `87bbcb0ca`
- `fix/ppi-quantisation-privacy-pr-20260824` at `be30dfff6`
- `fix/notifications-group-email-link-pr-20260824` at `b017f615f`
- `fix/ci-deployment-metadata-id-pr-20260824` at `4c6b373b`
- `test/notifications-isolation-pr-20260824` at `88002d41`
- `test/notification-submission-deadline-isolation-pr-20260824` at `2f3df4f5`
- `test/task-upload-isolation-pr-20260824` at `44464bad`
- `fix/cpd-recommended-ordering-20260824` at `9e7fa49dd`

Reviewer-ready web repairs extracted from the locked revision or its demo
follow-up:

- `fix/cpd-due-date-warning-integration-20260824` at `ddf31f970`
- `fix/cpd-deadline-chip-alignment-pr-20260824` at `65f913609`
- `fix/cpd-completed-task-order-pr-20260824` at `986601624`
- `fix/cpd-recommended-ordering-20260824` at `cbe315b2a`
- `fix/ppi-live-task-adapter-20260824` at `641ff270a`
- `fix/ppi-demo-peer-median-current-date-20260824` at `fdddd2202`
- `fix/web-node-22-toolchain-pr-20260824` at `27f1012bf`
- `fix/web-angular-test-timeout-pr-20260824` at `e513ca336`

Reviewer-ready deploy repairs in the documented stack:

- `fix/deploy-combined-demo-consistency-20260824` at `329f2e2`
- `fix/deploy-compose-schema-cleanup-pr-20260824` at `7c256c4`
- `config/ppi-production-values-20260824` at `0b076bd` (deploy PR #11)
- `fix/deploy-ppi-privacy-floor-20260824` at `9bb524f` (superseded extraction)
- `docs/deploy-all-features-runbook-pr-20260824` at `b43b831`

The material repairs close a CPD task-definition privacy leak, PPI singleton
disclosure at cohort 20, CPD completed-task ordering, a missing group-change
email link, notification-test state leakage, invalid deployment-workflow output
references, the live task-level PPI web adapter, Node toolchain drift, and
cross-feature Compose inconsistencies. The final API test repair also cleans
external upload files deterministically and updates the authenticated settings
contract for the merged push fields.

## Validation evidence

Web at the locked revision:

- all 87 test files: 459 passed, 1 existing todo, 0 failures
- type-check: passed
- lint: passed
- focused CPD tests: 46 passed
- production build: passed with the supported Node 22 Docker toolchain
- ancestry and whitespace checks: passed

API at the locked revision:

- clean database creation, all migrations, and `db:populate`: passed
- RuboCop: 344 files, 0 offences
- actionlint: 0 errors
- CPD privacy regression: 1 run, 41 assertions, 0 failures/errors
- PPI endpoint: 38 runs, 2,599 assertions, 0 failures/errors
- PPI service/job pack: 35 runs, 93 assertions, 0 failures/errors
- notification mailers: 19 runs, 61 assertions, 0 failures/errors
- broad notification pack at seed 43066: 182 runs, 1,003 assertions,
  0 failures/errors
- complete Task model file at seed 10236 with TexLive: 29 runs,
  237 assertions, 0 failures/errors/skips
- complete service-backed repository suite at seed 10236: 1,038 runs,
  12,976 assertions, 0 failures/errors/skips; MariaDB, Redis, TexLive, and
  JPlag were all attached with fresh external state

Deploy at this branch:

- all base/overlay Compose configurations: valid
- YAML, shell, Node helper syntax, ancestry, and whitespace checks: passed
- the locked sibling API/web heads built successfully with the normal local-path
  overlay, and `bundle exec rake db:populate` completed against the same Compose
  project
- at `2026-08-23T20:07:55Z`, API, web, MariaDB, Redis, Sidekiq, and Mailpit were
  all running; web and Mailpit returned HTTP 200, while the unauthenticated API
  settings probe returned the expected HTTP 419 authentication response
- the authenticated browser smoke covered student and convenor logins, all four
  units on the cross-unit dashboard, its Due Date sorting control, the live task
  route `/projects/2/dashboard/1.1P`, notification preferences, and the COS10001
  convenor inbox
- the task-level PPI rendered its privacy-safe seeded state, `Peer progress is
  currently unavailable.`; unit-summary and burndown were not treated as live
- the current development bundle had zero error-level browser-console entries.
  The decisive checks used the equivalent clean origin `127.0.0.1:4400` after a
  pre-existing `localhost` service-worker cache initially served an older
  bundle; no browser data was deleted. Non-blocking Angular/Material development
  warnings remained for an `aria-hidden` badge and `strokeDashoffset` animation
- push prerequisites were present: the `push_subscriptions` table existed,
  `PushNotificationService.configured?` was true, and both `ngsw.json` and the
  84,643-byte service worker returned HTTP 200. Browser registration was not
  changed because the in-app browser reported notifications as blocked
- an end-to-end notification smoke returned HTTP 201, queued through Sidekiq,
  and increased Mailpit from zero to one message. Mailpit received
  `OnTrack: New notification` from `noreply@doubtfire.local`; the synthetic task
  comment and in-app notification were then removed, with zero notification
  email jobs in either the retry or dead set
- API/worker logs showed successful migrations, Redis connection, SMTP delivery,
  and job completion with no corresponding runtime errors

## Deliberate upstream limitations

These are feature-scope limitations already present in the source branches,
not hidden merge failures:

- The task-level PPI widget uses the live authorised API. The unit-summary and
  burndown views remain explicit demo/mock views because no corresponding
  backend aggregate contracts exist.
- The CPD Recommended ordering mode still uses its documented placeholder
  recommendation logic.
- Future-dated, rollover, copied, and import-created task notifications remain
  outside the first EN implementation.
- Seeded PPI sample cohorts have only eight students per grade and PPI defaults
  to disabled per unit. An unsuppressed percentage demo needs PPI enabled and a
  target-grade cohort of at least 21.
- The inherited web dependency graph still reports 14 audit findings: three
  low, five moderate, five high, and one critical. This integration did not
  change or claim to resolve them.
- The production Compose file remains a deployment template, not a
  production-ready deployment.

Production PPI values still require deployment review. Local development uses
the API-enforced privacy floor `DF_PPI_MINIMUM_COHORT_SIZE=21` and a 48-hour
staleness window.
