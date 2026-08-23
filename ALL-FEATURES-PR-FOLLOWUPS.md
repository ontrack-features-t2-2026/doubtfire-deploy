# OnTrack 11.0.x all-features PR follow-up index

This is the coordination record for turning the validated CPD, PPI, Email
Notifications, and Mobile Notifications demo into reviewable pull requests.
It was refreshed from GitHub at `2026-08-23T22:02:50Z`.

The large `integration/11.0.x-all-features-20260824` branches are validation
inputs, not review branches. API draft PR #60 and web draft PR #81 publish
those exact heads for coordination and submodule reachability only; do not
merge either integration PR directly. Review the small branches below,
preserve their stated bases, and keep unrelated calendar, waveform,
language-notice, and task-comment work out of this stack.

## Recommended review and merge order

1. Finish the existing feature PRs into their current shared feature branches.
2. Review each new API and web repair against its natural feature base.
3. Coordinate the API and deploy PPI privacy-floor changes. The deploy value
   can land first; do not land the API floor of 21 while deployment still
   supplies 20, because the endpoint will fail closed with HTTP 503.
4. Merge the independent `11.0.x` CI, test-isolation, Compose, and deployment
   fixes.
5. Review the combined deploy branches as a stack. Keep downstream PRs in
   draft until their bases merge, then rebase or retarget them to the updated
   `11.0.x` branch.
6. Publish the API and web integration heads before publishing the deploy lock,
   because its submodule pointers must resolve on GitHub.

For every PR, use the repository template, name the exact target branch, link
the prerequisite PRs, include the focused test results, and request review from
the owner of the affected feature. Prefer squash merging the one-commit repair
branches. Do not squash coordination merge branches.

## Existing open PRs on GitHub

The original feature PRs are non-draft; the newly published repair and
integration PRs are drafts. `BLOCKED` below is GitHub's current merge state and
generally means required review or checks are still outstanding; it does not
make the branch part of this integration automatically.

### `doubtfire-deploy`

| PR | Head → base | Role in this stack |
| --- | --- | --- |
| [#11](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/11) | `config/ppi-production-values-20260824` → `11.0.x` | Preferred deploy half of the PPI floor rollout; sets development and production values to 21/48. Currently `BLOCKED`. |
| [#10](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/10) | `chore/sidekiq-worker` → `11.0.x` | Required by the notifications environment; currently `BLOCKED`. |
| [#9](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/9) | `bugfix/harsh-notifications` → `11.0.x` | Teams workflow only; keep separate from the product-feature stack. |

### `doubtfire-api`

| PRs | Heads → bases | Role in this stack |
| --- | --- | --- |
| [#43](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/43) | `email/sidekiq-worker` → `feature/notifications` | Notification email queue prerequisite. |
| [#46](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/46) | `security/ppi-authorisation-tests` → `feature/peer-progress-indicator` | PPI security prerequisite. |
| [#47](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/47), [#48](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/48), [#49](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/49), [#50](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/50), [#52](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/52) | `email/*` → `feature/notifications` | Email notification feature and test PRs. |
| [#51](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/51) | `security/v2-push-lock-screen-review` → `feature/notifications` | Mobile notification payload security prerequisite. |
| [#41](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/41), [#42](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/42), [#45](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/45) | Test, Teams-workflow, and test-performance heads → `11.0.x` | Present in the validated integration history, but review and merge separately from product features. |

All eleven API PRs above currently report `BLOCKED`.

### `doubtfire-web`

| PRs | Heads → bases | Role in this stack |
| --- | --- | --- |
| [#58](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/58), [#59](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/59), [#60](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/60), [#61](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/61), [#62](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/62), [#72](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/72) | CPD heads → `feature/cross-unit` | CPD feature, fixes, and documentation prerequisites. |
| [#73](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/73) | `chore/ppi-cleanup` → `feature/peer-progress-indicator` | PPI cleanup prerequisite. |
| [#69](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/69), [#70](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/70), [#71](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/71) | Push/PWA heads → `feature/notifications` | Mobile notification and PWA prerequisites. |
| [#57](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/57) | `bugfix/harsh-notifications` → `11.0.x` | CI workflow input only; keep separate from product features. |
| [#52](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/52), [#53](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/53), [#54](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/54), [#63](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/63), [#64](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/64), [#67](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/67), [#68](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/68) | Calendar, task-comment, language-notice, and waveform heads | Out of scope; do not merge into an all-features repair branch. |

Web PRs #69 and #70 currently report `CLEAN`; the other original in-scope web
PRs report `BLOCKED`. Among the out-of-scope PRs, #52, #64, and #68 report `CLEAN`,
#53 reports `UNSTABLE`, and the remainder report `BLOCKED`.

## New API repair PRs

| Branch and local head | PR base | Dependency and action |
| --- | --- | --- |
| [#59](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/59) — `fix/cpd-task-definition-privacy-pr-20260824` at `8b2250b94` | `feature/cross-unit` | Draft security/privacy fix to merge before CPD reaches `11.0.x`. |
| [#55](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/55) — `fix/ppi-quantisation-privacy-pr-20260824` at `c29b33cb` | `feature/peer-progress-indicator` | Coordinate with deploy PR #11; deployment value 21 must be in place before this API floor lands. |
| [#56](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/56) — `fix/notifications-group-email-link-pr-20260824` at `b017f615f` | `feature/notifications` | Draft notification-link repair. |
| [#54](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/54) — `fix/ci-deployment-metadata-id-pr-20260824` at `4c6b373b` | `11.0.x` | Draft independent deployment-workflow fix. |
| [#57](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/57) — `test/notifications-isolation-pr-20260824` at `88002d41` | `feature/notifications` | Draft test fix that authenticates push-settings requests and removes shared authentication state. |
| [#58](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/58) — `test/notification-submission-deadline-isolation-pr-20260824` at `2f3df4f5` | `email/submitted-for-marking` | Draft stacked on API PR #48; currently `UNSTABLE`. Retarget to `feature/notifications` after #48 merges. |
| [#53](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/53) — `test/task-upload-isolation-pr-20260824` at `44464bad` | `11.0.x` | Draft independent cleanup of upload-conversion fixtures. |

[API draft #60](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/60)
publishes the combined integration head. Keep it draft and use it only for
coordination and final checks; the small PRs above are the review path.

`test/notifications-settings-contract-pr-20260824` currently has no unique
commit beyond `feature/notifications`. The remaining settings-contract update
depends on both the notification push fields and the `11.0.x` settings split.
Do not open an empty PR; extract it only after those histories share a base.

## New web repair PRs

| Branch and local head | PR base | Dependency and action |
| --- | --- | --- |
| [#74](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/74) — `fix/cpd-due-date-warning-integration-20260824` at `ddf31f970` | `feature/cross-unit` | Draft prerequisite reconstruction of the dashboard due-date warning feature. It deliberately excludes unrelated unit-task-editor churn. |
| [#75](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/75) — `fix/cpd-deadline-chip-alignment-pr-20260824` at `65f913609` | `fix/cpd-due-date-warning-integration-20260824` | Requested icon/text centring fix. Keep it stacked; retarget to `feature/cross-unit` after #74 merges. Currently `UNSTABLE`. |
| [#80](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/80) — `fix/cpd-completed-task-order-pr-20260824` at `ab022044e` | `feature/cross-unit` | Draft independent ordering fix that keeps completed tasks below active work. |
| [#77](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/77) — `fix/ppi-live-task-adapter-20260824` at `641ff270a` | `feature/peer-progress-indicator` | Draft connection from task widget to the authorised live API. |
| [#79](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/79) — `fix/ppi-demo-peer-median-current-date-20260824` at `fdddd2202` | `feature/peer-progress-indicator` | Draft fix that stops the median at today instead of stretching it to 100%. |
| [#78](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/78) — `fix/web-node-22-toolchain-pr-20260824` at `27f1012bf` | `11.0.x` | Draft supported-Node toolchain alignment. |
| [#76](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/76) — `fix/web-angular-test-timeout-pr-20260824` at `e513ca336` | `11.0.x` | Draft CI timeout adjustment used by the validated full suite. |

[Web draft #81](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/81)
publishes the combined integration head. Keep it draft and use it only for
coordination and final checks; the small PRs above are the review path.

## New deploy PR stack

| Branch and local head | Review base | Dependency and action |
| --- | --- | --- |
| `integration/notifications-environment-20260823` at `41f3f66` | `11.0.x` | Depends on deploy PR #10 and the notification feature branches. Rebase after #10 merges so its diff contains only notification-environment work. |
| `integration/peer-progress-indicator-live-20260823` at `ecf4e8d` | `11.0.x` | PPI live-demo overlay; depends on the PPI API and web feature heads for an end-to-end demo. |
| `integration/deploy-all-features-foundation-20260824` at `e34c00b` | coordination only | Merges the two preceding deploy inputs. Push only as a stacked-PR base; do not merge it directly. |
| `fix/deploy-combined-demo-consistency-20260824` at `329f2e2` | `integration/deploy-all-features-foundation-20260824` | One-commit cross-feature Compose fix for web startup, worker image parity, and notification links. |
| `fix/deploy-compose-schema-cleanup-pr-20260824` at `7c256c4` | `integration/deploy-all-features-foundation-20260824` | Removes the remaining obsolete Compose schema declarations after the notification environment removes the first two. |
| `fix/deploy-ppi-privacy-floor-20260824` at `9bb524f` | `11.0.x` | Clean reconstruction of the original local fix, now superseded by the more complete deploy PR #11. Do not open a duplicate PR. Rebase downstream coordination branches after #11 merges. |
| `integration/deploy-all-features-pr-ready-20260824` at `aae51de` | coordination only | Combines the reviewed deploy fixes for downstream documentation. Push only as a stacked-PR base. |
| `docs/deploy-all-features-runbook-pr-20260824` at `b43b831` | `integration/deploy-all-features-pr-ready-20260824` | One-commit combined-demo runbook update. Retarget to `11.0.x` after the deploy prerequisites merge. |
| `chore/deploy-all-features-integration-lock-pr-20260824` | `docs/deploy-all-features-runbook-pr-20260824` | Locks validated API/web revisions and carries this index. Keep draft until both referenced component commits are published. |

## Coordination-only integration heads

These reproduce the working demo and are useful for final smoke testing, but
their large histories are not appropriate review diffs:

| Repository | Branch | Validated head |
| --- | --- | --- |
| API | `integration/11.0.x-all-features-20260824` | `2f945c71203a47f8777ad158966a2cdff765109a` |
| Web | `integration/11.0.x-all-features-20260824` | `36be84f30d80c237e97a0f15b607ec0b1b3a4b57` |
| Deploy | `integration/11.0.x-all-features-20260824` | `686a81a6e40cd1045638077e539ec147649eb5ca` |

## Known work that is not PR-ready

Keep these as separate backlog items rather than silently bundling them into
one of the PRs above:

- `fix/production-ready-compose-20260824`: production Compose remains a
  template and needs a separately scoped deployment-hardening review.
- `fix/api-production-runtime-hardening-20260824` at `b5326e30`: production
  worker startup hardening, outside the validated all-features stack.
- `fix/npm-audit-20260824`: inherited web dependency findings need a dedicated
  dependency-upgrade plan and regression pass.
- `fix/cpd-recommended-ordering-20260824`: the documented recommendation
  placeholder needs a product decision before implementation.
- Unit-summary and burndown PPI remain explicitly labelled demo data until an
  authorised backend aggregate contract is designed and reviewed.

## Validation recorded for the extracted branches

- All seven API repair branches are clean, pass whitespace checks, and pass
  exact-file RuboCop. The upload test file retains the same 255 inherited
  offences before and after its isolation-only diff. Direct
  natural-base test runs are currently blocked because those older
  `Gemfile.lock` files do not match the already-built current integration
  image. Do not present the full integration suite as branch-specific proof;
  run each branch in CI (or rebuild its exact base image) after publication.
- CPD due-date prerequisite: 41 focused tests, application type-check,
  focused lint, and formatting passed.
- Deadline-chip alignment: 13 focused tests, application type-check, focused
  lint, and formatting passed.
- Completed-task ordering: all 28 focused dashboard tests, application
  type-check, focused lint, formatting, and whitespace checks passed.
- Deploy stack: the base, local-path, PPI-live, full-development, and
  production Compose configurations rendered successfully. Every YAML file
  parsed, every shell script passed syntax checking, both Node helper modules
  passed syntax checking, and whitespace checks passed.
- The full integration validation evidence remains in
  `ALL-FEATURES-INTEGRATION.md`; individual PR descriptions should quote only
  the evidence relevant to their own diff.

## Close-out checklist

- [ ] Every PR has the intended base and contains no merge-only integration history.
- [ ] API PPI PR #55 and deploy PPI-values PR #11 cross-link each other.
- [ ] The deadline-chip PR links its due-date-warning prerequisite.
- [ ] Existing feature PRs have required reviews and green checks.
- [ ] Downstream deploy drafts are rebased or retargeted after prerequisites merge.
- [ ] API and web lock SHAs are reachable from published branches.
- [ ] Final combined Compose, browser, notification-email, CPD, and PPI smoke tests pass.
- [ ] This index is updated with final GitHub PR numbers and merge status.
