# Removable all-features demo

This folder owns the local CPD, PPI, email-notification, in-app-notification,
and mobile/push demonstration runtime. It deliberately does not reuse the
older `notifications-demo` database, Redis state, student work, temporary
files, or Node dependencies.

The matching API scenario is deterministic and development-only. It creates
generic `demo_*` accounts with `.invalid` email addresses, a privacy-safe
anonymous peer cohort with a convincing spread of task states, cross-unit tasks
with useful deadline states, and a small curated notification set. It never
creates a browser push subscription. The PPI fixture includes visible working,
ready-for-feedback, fix-and-resubmit, redo, complete, and fail segments while
retaining every canonical status key in the API contract.

## Start and populate

This demo uses the familiar ports 4400, 3200, and 8225. Stop any older local
stack using those ports before starting it. Stopping the older stack is enough;
do not remove its volumes.

For a fresh clone, initialise the exact API and web revisions first:

```bash
git submodule update --init --recursive
./demo.sh sources
```

`sources` prints the selected paths and revisions so they can be compared with
the release handover. Then use the one-command preparation path:

```bash
./demo.sh prepare
```

`prepare` builds the selected sources, starts the isolated services, applies
migrations, installs the API's standard roles and task states, recreates the
deterministic records, restarts the application services, and runs the guarded
scenario verifier. The database has a readiness check, so the seed waits for a
fresh MariaDB instance rather than racing it. Preparation is safe to run again
whenever the scenario needs to be reset.

The verifier fails unless the remaining cohort after excluding `demo_student`
meets the configured peer floor, its snapshot and the student's project/task
context are consistent and fresh, the compact completed percentage is present, the
additive submitted compatibility metric is present, the complete canonical
status distribution is present, and the representative detailed segments are
non-zero after privacy quantisation. It exercises the same reader-subtraction
and whole-vector ambiguity path used by the live API; it never prints peer
identities, the cohort size, or raw counts.
Status buckets are rounded independently for privacy and are not expected to
sum to exactly 100%.

To control the steps separately, use:

```bash
./demo.sh start
./demo.sh seed
./demo.sh verify
```

Then open:

- OnTrack: <http://localhost:4400>
- API: <http://localhost:3200>
- Mailpit: <http://localhost:8225>

Sign in as `demo_student` with password `password`. The web account menu links
to **Demo controls**, where the local demonstration data can be turned on and
off. The switch does not grant browser notification permission or create a
push subscription.

For the requested Peer Progress walkthrough:

1. Open **Demo controls**, turn **Demo mode** on, and allow the page to reload.
2. Open **Foundations of OnTrack** (`DEMO10001`) and the **Due Within Seven
   Days** (`DUE7`) task.
3. Scroll below the submission area. The compact Peer Progress Indicator is
   deliberately placed there rather than near the task heading.
4. Use the small **Advanced** control on the indicator to reveal the coloured
   status distribution, including redo and fix-and-resubmit.
5. Return to compact mode, then turn **Display anonymous peer progress
   statistics** off and on in profile settings. A new seeded account starts
   with this preference on.
6. Use the local demo controls to show the insufficient-cohort and
   advanced-vector-unavailable examples. They must explain why details are not
   available and offer safe next actions without exposing a cohort count. The
   90% and 110% rounded-vector previews demonstrate that independently rounded
   statuses keep their own 0–100 scales rather than being visually
   renormalised.

The task-level eligible state comes from the guarded local API seed. Labelled
edge-state previews in the demo controls are client fixtures that can be present
in the compiled web bundle, but they are runtime-inaccessible in production:
production sets `enableDemoTools` to false, the demo route redirects through its
production/demo guard, and the peer-progress service passes authorised API data
through unchanged. Production therefore cannot activate a fabricated preview
or substitute it for live peer progress.

To build from isolated worktrees instead of the normal sibling checkouts:

```bash
DF_DEMO_API_PATH=/absolute/path/to/api-worktree \
DF_DEMO_WEB_PATH=/absolute/path/to/web-worktree \
./demo.sh prepare
```

Use the same two path variables for every later helper command in that shell.

Source discovery is deterministic: explicit `DF_DEMO_API_PATH` and
`DF_DEMO_WEB_PATH` values win, followed by complete sibling checkouts, then the
deploy repository submodules. The helper fails before Compose starts if the API
demo seed task or web demo store is missing. A fresh clone can therefore use
`git clone --recurse-submodules`, while contributors can continue to point at
isolated worktrees without editing Compose files.

## Inspect or stop

```bash
./demo.sh status
./demo.sh logs
./demo.sh stop
```

## Remove it completely

The destructive action is guarded and targets only the Compose project named
`all-features-demo`:

```bash
ALL_FEATURES_DEMO_CONFIRM_DESTROY=1 ./demo.sh destroy
```

This removes the demo containers, network, database, Redis state, student work,
temporary files, and Node dependency volume. It cannot select the historical
`notifications-demo` project because the project name is fixed in the helper.

To remove the runtime from the repository later, delete this directory and the
short link to it in `RUNNING-LOCALLY.md`. The ordinary development environment
does not depend on it.
