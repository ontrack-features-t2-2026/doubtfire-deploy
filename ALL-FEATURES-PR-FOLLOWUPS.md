# OnTrack 11.0.x all-features PR follow-up index

This is the central coordination record for turning the validated CPD, Peer
Progress Indicator (PPI), Email Notifications, and Mobile Notifications demo
into reviewable pull requests. GitHub Issues are disabled in these repositories,
so [deploy PR #12](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/12)
and this file are the canonical tracker.

GitHub state was refreshed at `2026-08-24T00:02:45Z`. Check states are a
snapshot and must be rechecked immediately before merging. `BLOCKED` usually
means the repository ruleset is waiting for review; it does not imply a failing
test unless a failure is called out below.

The large API and web `integration/11.0.x-all-features-20260824` branches are
validation inputs, not the preferred review path. Keep their umbrella PRs in
draft and merge the focused PRs into their natural feature branches.

## Recommended review and merge order

1. Merge the existing feature PRs into their shared feature branches after the
   required review and green checks.
2. For CPD recommendations, the review dependency was
   [API #59](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/59)
   -> [API #61](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/61)
   -> [web #84](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/84).
   Live merges have nested #61 into API #59, and web #84 plus its route-test
   follow-up #85 into web #72. Both parent rollups are now green. The remaining
   review/merge path is therefore API #59, then web #72.
3. For PPI, review [API #62](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/62),
   which now contains merged privacy-floor PR #55. Coordinate its rollout with
   [deploy #11](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/11):
   the deploy value can land first, but do not deploy the API floor of 21 while
   deployment still supplies 20, because the endpoint will fail closed.
4. Merge the independent `11.0.x` CI, test-isolation, dependency, Compose, and
   production-hardening PRs separately from the product-feature branches.
5. Review deploy #12 last. Deploy PRs #13-#17 and #19 have already been merged
   through its branch, so #12 is now the single open deploy integration PR.
6. After the focused API/web PRs land, refresh the umbrella heads and deploy
   gitlinks, rerun the complete integration validation, and only then merge the
   release-level integration.

Prefer squash merging one-commit repair branches. Preserve merge commits in
coordination branches so the feature histories remain traceable. Do not merge
an umbrella PR merely to bypass a focused PR's review.

## Current deploy coordination

| PR | State and checks | Role |
| --- | --- | --- |
| [#12](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/12) — `integration/deploy-all-features-foundation-20260824` at `6609697d5ebf` -> `11.0.x` | Open, ready for review, `BLOCKED`; no status check is configured on the latest merge commit | Canonical tracker and top-level notification/PPI integration. It now contains merged #13-#17 and #19. |
| [#10](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/10) — `chore/sidekiq-worker` -> `11.0.x` | Open, `BLOCKED`; 1/1 checks passing | Sidekiq worker prerequisite for the notifications environment. |
| [#11](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/11) — `config/ppi-production-values-20260824` at `0b076bda442f` -> `11.0.x` | Open, `BLOCKED`; 1/1 checks passing | Production PPI cohort/staleness values. Coordinate with API #62. |
| [#18](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/18) — `fix/production-ready-compose-20260824` at `c8554ebd2257` -> `11.0.x` | Open, `BLOCKED`; 2/2 checks passing | Separate fail-closed production Compose hardening. |
| [#9](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/9) | Open, `BLOCKED`; 1/1 checks passing | Teams workflow only; outside the product-feature stack. |

Merged into deploy #12's branch:

- #13 Compose schema cleanup
- #14 combined-demo consistency
- #15 PR-ready coordination merge
- #16 combined-demo runbook
- #17 integration lock and the original tracker
- #19 privacy-safe PPI demo cohort documentation

These merged PRs are present in #12, but they are not in `11.0.x` until #12 is
reviewed and merged.

## Current API follow-ups

| PR | State and checks at refresh | Dependency and action |
| --- | --- | --- |
| [#59](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/59) — `fix/cpd-task-definition-privacy-pr-20260824` at `5278ddd54fd1` -> `feature/cross-unit` | Open, ready, `BLOCKED`; 4/4 checks passing. Unit suites passed in 29m31s and 31m51s | Carries the privacy repair and merged recommendation API #61. This is the remaining API parent review gate. |
| [#61](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/61) — recommendation contract at `ca20f6bfa584` | Merged into #59 | The authoritative #59 parent rollup subsequently completed 4/4 green. |
| [#62](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/62) — `style/ppi-sample-data-lint-pr-20260824` at `1fbbd75842d5` -> `feature/peer-progress-indicator` | Open, ready, `BLOCKED`; 4/4 checks passing | Contains merged #55, so it is now the single PPI lint/privacy review path. Coordinate with deploy #11. |
| [#53](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/53) — upload test isolation | Open, ready, `BLOCKED`; 6/6 passing | Independent `11.0.x` test repair. |
| [#54](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/54) — deployment metadata IDs | Open, ready, `BLOCKED`; 6/6 passing | Independent `11.0.x` workflow repair. |
| [#56](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/56) — notification group email link | Open, ready, `BLOCKED`; 6/6 passing | Merge into `feature/notifications`. |
| [#57](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/57) — notification settings isolation | Open, ready, `BLOCKED`; 6/6 passing | Merge into `feature/notifications`. |
| [#60](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/60) — combined API umbrella at `7f912987d489` | Open draft, `BLOCKED`; 7/7 passing | Coordination/final-validation only; it now includes merged demo-cohort PR #64. |
| [#63](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/63) — production runtime hardening | Open, ready, `BLOCKED`; 4/4 checks passing | Separate production-readiness review, not part of the locked demo. |

API #55 was merged into #62 rather than the release branch. API #61 was merged
into #59 rather than `feature/cross-unit`. API #58 was merged into its parent
email PR #48; #48 remains open with 4/4 checks passing. The original in-scope
API feature PRs #41-#43 and #45-#52 remain open. Their checks are green, and
GitHub marks them `BLOCKED` pending review.

`test/notifications-settings-contract-pr-20260824` still has no unique commit
beyond `feature/notifications`. Do not open an empty PR; extract the remaining
contract update only after the push fields and `11.0.x` settings split share a
base.

## Current web follow-ups

| PR | State and checks at refresh | Dependency and action |
| --- | --- | --- |
| [#72](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/72) — `docs/cpd-sizing-investigation` at `47978658eacc` -> `feature/cross-unit` | Open, ready, `BLOCKED`; 6/6 checks passing | Carries merged #74, #75, #80, #82, #84, and #85. This is the remaining web parent gate after API #59. |
| [#84](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/84) — recommendation contract/lifecycle at `71484082c926` | Merged into #72 with both test jobs failing | The failure was isolated to the route spec missing a `TaskService2` provider. The production implementation, lint, and build jobs passed. |
| [#85](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/85) — route provider follow-up at `b867365cc36e` | Merged into #72; 8/8 checks passing | Tiny green regression follow-up for #84. |
| [#75](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/75) — centred deadline warning icons | Merged with 11/11 checks passing | Requested overdue/3-day/7-day alignment fix; now carried by #72. |
| [#77](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/77) — live task-level PPI adapter | Open, ready, `BLOCKED`; 10/10 passing | Merge into `feature/peer-progress-indicator`. |
| [#79](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/79) — realistic demo peer median | Open, ready, `BLOCKED`; 9/9 passing | Stops the demo median at today (about 40% at the seeded date) instead of showing every task complete. |
| [#76](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/76) — Angular CI timeout | Open, ready, `BLOCKED`; 12/12 passing | Independent `11.0.x` CI repair. |
| [#78](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/78) — Node 22 alignment | Open, ready, `BLOCKED`; 12/12 passing | Independent `11.0.x` toolchain repair. |
| [#81](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/81) — combined web umbrella at `36be84f30d80` | Open draft, `BLOCKED`; 10/10 passing | Coordination/final-validation only. |
| [#83](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/83) — inherited npm audit fix | Open, ready, `BLOCKED`; 10/10 passing | Separate dependency-security PR created outside this extraction; review it independently. |

Web #74 (due-date warning states), #75 (chip alignment), #80 (completed-task
ordering), #82 (the first recommendation UI), #84 (final contract/lifecycle),
and #85 (route-test provider) are merged into the #72/docs chain. They are not
in `feature/cross-unit` until #72 is reviewed and merged.

The original in-scope web CPD/PPI/notification PRs #57-#62, #69-#73 remain
open. #72's complete replacement rollup is green. Calendar, waveform,
language-notice, and task-comment PRs remain outside this all-features stack.

## Coordination-only integration heads

These reproduce the working demo and are useful for final smoke testing, but
their large histories are not the preferred review diffs:

| Repository | Published coordination PR/head | Status |
| --- | --- | --- |
| API | [#60](https://github.com/ontrack-features-t2-2026/doubtfire-api/pull/60) at `7f912987d489` | Draft; 7/7 checks passing. The deploy gitlink still locks the previously fully validated `2f945c71203a47f8777ad158966a2cdff765109a`. |
| Web | [#81](https://github.com/ontrack-features-t2-2026/doubtfire-web/pull/81) at `36be84f30d80` | Draft; 10/10 checks passing and matches the deploy gitlink. |
| Deploy | [#12](https://github.com/ontrack-features-t2-2026/doubtfire-deploy/pull/12) at `6609697d5ebf` | Open top-level integration; no status check is configured on its latest merge commit. |

The locked API/web revisions do not yet contain the final CPD recommendation
work now nested in API #59 and web #72. After those parent PRs are accepted,
refresh both coordination heads and deploy gitlinks, then rerun the lock
validation.

## Validation already recorded

- Full locked web revision: 87 files, 459 passing tests, 1 existing todo,
  type-check, lint, 46 focused CPD tests, and production build all passed.
- Deadline-chip alignment: 13 focused tests, type-check, targeted lint,
  formatting, browser measurement, and whitespace checks passed. The icon box
  and line height are both 14px inside a 20px chip with equal vertical space.
- Realistic PPI demo curve: focused tests passed and the seeded current-date
  peer median is approximately 42%, rather than 100%.
- Full locked API revision: 1,038 runs and 12,976 assertions with no failures,
  errors, or skips; 344-file RuboCop completed with no offences.
- API #61 local focused proof before publication: recommender tests completed
  with 14 runs/57 assertions; student-safe projects payload completed with
  1 run/46 assertions; affected-file RuboCop and syntax checks passed.
- Web #85 regression proof before publication: 63 test files completed with
  148 passing tests and 1 existing todo; type-check, lint, formatting, and
  whitespace checks passed.
- Deploy stack: all base and overlay Compose configurations rendered; every
  YAML file parsed; shell and Node helpers passed syntax checks; whitespace
  checks passed.
- The browser smoke covered student and convenor login, the four-unit CPD
  dashboard, due-date sorting, a live task PPI route, notification preferences,
  and the convenor inbox. Email delivery through Sidekiq and Mailpit succeeded.
- Push prerequisites and the service worker were present. Browser notification
  permission remains a manual, user-granted site permission; application code,
  CI, and GitHub cannot silently grant it.

## Deliberate remaining limitations

- Task-level PPI uses the live authorised API. Unit-summary and burndown PPI
  remain explicitly labelled sample/demo data until authorised aggregate API
  contracts are designed and reviewed.
- Deploy #18 and API #63 are separate production-hardening reviews. The combined
  local demo must not be presented as production-ready until those changes and
  an environment-specific deployment review are complete.
- Web dependency remediation is isolated in external follow-up #83. Keep it
  separate from feature reviews so dependency changes receive their own
  regression and security review.
- A real browser push registration cannot be automated from GitHub or silently
  granted by application code. The user must allow notifications for the local
  site and trigger registration from the UI.

## Remaining follow-up checklist

- [x] Publish focused PRs and combined API/web umbrella PRs.
- [x] Merge web #74/#75/#80/#82 into the #72 CPD review chain.
- [x] Merge API #55 into #62 and API #58 into #48.
- [x] Merge deploy #13-#17 and #19 into central deploy PR #12.
- [x] Add web #85 for the #84 route-spec provider regression and merge both
      into #72.
- [x] Obtain a fully green API #62 check rollup after merged PPI PR #55.
- [x] Obtain a fully green web #72 parent check rollup after merged #84/#85.
- [x] Obtain a fully green API #59 parent rollup after merged #61; both unit
      suites and both RuboCop jobs passed.
- [ ] Obtain the required team approval and resolve every review thread on the
      focused PRs.
- [ ] Merge the remaining recommendation parents in order: API #59, then web
      #72. Their child PRs #61, #84, and #85 are already nested within them.
- [ ] Coordinate deploy #11 with the API #62 privacy-floor rollout.
- [ ] Refresh umbrella heads and deploy gitlinks after the focused PRs land.
- [ ] Repeat the final Compose, browser, notification-email, CPD, and PPI smoke
      tests against the refreshed lock.
- [ ] Manually allow notifications for the localhost site, reload, and verify a
      real push registration and delivery from a user gesture.
