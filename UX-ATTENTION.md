# Task attention and notification choices: release notes

This release connects student and teaching attention on the home page with clear
task actions, effective deadlines, searchable notification history, independent
email/push choices, and optional teaching summary emails. It includes the current
integrated web baseline, so previously merged summary preference fixes are also
present in the pinned package.

## Apply as one coordinated release

1. Review and accept the matching API and web PRs. Use the immutable revisions
   in `HANDOVER.md` and the Git submodule pointers; do not build from moving tips.
2. Rehearse the complete migration path from the institution's recorded schema
   on an isolated restore. The final schema is `20261001000001`.
3. Apply the migration before running new API and worker images. It copies old
   task, feedback and portfolio choices into separate email and push columns.
   Earlier feedback-based digest opt-outs stay off. Teaching summaries start off.
4. Deploy the paired API/worker and web images through the existing production
   runbook. `production/verify.sh` checks the exact schema plus the required
   student and teaching summary schedules, alongside existing workers.
5. Complete the acceptance walkthrough below before activating the release for
   real users. Keep the signed source/image/backup record required by
   `HANDOVER.md`.

## Compatibility and rollback

The API retains the notification array response for older clients. The new inbox
requests a bounded paginated response. New web clients need the paired API for
staff attention, filter metadata and the new current-user preferences.

Retain the forward schema during an application rollback where compatible. The
legacy category flag mirrors `email AND push`, so an older image does not turn
an opted-out external channel back on. Rolling the schema back discards separate
choices and must never happen while new API/worker instances are running. The
migration's down path preserves the conservative legacy flag and digest opt-outs.
Rollback can therefore suppress an otherwise selected channel until a user
chooses again; it favours respecting an opt-out. Restore API and worker images
together and verify schedules against the restored release.

A due-soon reminder is now unique to the project, task and effective deadline.
A later changed deadline can create one new reminder. Old unkeyed history cannot
prove its original deadline, so an eligible task may receive one keyed reminder
on the first sweep after upgrade. Subsequent sweeps deduplicate that deadline.

## Validation and remaining acceptance

Local validation used disposable databases and synthetic users. The web suite,
production build, API notification/attention regressions, migration rehearsal,
production configuration tests, PWA/release-helper tests and Nginx upload checks
are recorded in the linked PRs. The migration was explicitly exercised through
down/up/down/up in a separate disposable database, including old false choices,
independent channels and a retained explicit digest cadence.

The live browser walkthrough was blocked because the browser tool could not
verify the local computer's security policy. It is not claimed complete. The
institution still owns real SSO, SMTP, calendar refresh, physical-device push,
screen-reader and production-sized migration acceptance.

Use the web `docs/ux-attention/README.md` walkthrough with synthetic accounts:
student priorities and task actions; extension/date agreement; settings
save/reload/discard; inbox filters and keyboard paging; and tutor/unit-chair
counts matched to assigned inbox work. Include above-target submitted tasks,
observers, unrelated staff and empty/error states. Check a real controlled inbox
and device for selected email/push channels and opt-in teaching summaries.

Teaching emails contain counts and unit codes, not student names or feedback.
A tutor's summary follows their assigned tutorial streams; unit chairs see their
unit. System administrator status alone does not create a new cross-unit view.

Calendar subscriptions refresh on the provider's schedule. A downloaded file is
a snapshot, and OnTrack remains authoritative for recent date changes. These
changes do not alter academic submission, marking or extension policy.
