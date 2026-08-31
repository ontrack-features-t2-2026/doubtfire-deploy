# Removable all-features demo

This folder owns the local CPD, PPI, email-notification, in-app-notification,
and mobile/push demonstration runtime. It deliberately does not reuse the
older `notifications-demo` database, Redis state, student work, temporary
files, or Node dependencies.

The matching API scenario is deterministic and development-only. One canonical
registry creates generic `demo_*` accounts with `.invalid` email addresses, the
exact ten-task lifecycle fixture (60% submitted and 10% complete), three
privacy-safe PPI variants, one insufficient-cohort unit, seven distinct
notification events, and one synthetic three-person group. It never creates a
browser push subscription. The PPI responses retain every canonical status key
and never expose raw counts, cohort sizes, names, usernames, or email addresses.

The demo worker consumes the user-facing `mailers` and `notifications` queues.
It deliberately leaves `default` untouched because this local stack does not
include every service required by the general background-job workload.

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

The verifier fails unless the ten-task lifecycle percentages, all three
available PPI variants, the one insufficient-cohort state, all seven unique
notification hooks, and the synthetic group membership are internally
consistent. It exercises the same reader-subtraction and whole-vector ambiguity
path used by the live API; it never prints peer identities, the cohort size, or
raw counts.
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

Sign in as `demo_student` with password `password`. Only this account in this
isolated database can read `GET /api/demo/scenario`; every other environment or
account receives a generic 404. The response is `private, no-store`. The web
keeps it in a dedicated in-memory adapter and never inserts it into project,
unit, task, notification, or group caches.

The account menu then links to **Demo controls**. Turning the walkthrough on
changes only local presentation hooks. Turning it off is a genuine pass-through:
normal API responses are not filtered, hidden, replaced, or cached differently.
The switch does not reload the app, grant browser notification permission, or
create a push subscription.

For the requested Peer Progress walkthrough:

1. Open **Demo controls** and turn **Demo** on.
2. Use the labelled **Peer Progress Indicator** link. It opens **Foundations of
   OnTrack** (`DEMO10001`) at **Due Within Seven Days** (`DUE7`).
3. Scroll below the submission area. The compact Peer Progress Indicator is
   deliberately placed there rather than near the task heading.
4. Use the small **Advanced** control on the indicator to reveal the coloured
   status distribution, including redo and fix-and-resubmit.
5. Return to compact mode, then turn **Display anonymous peer progress
   statistics** off and on in profile settings. A new seeded account starts
   with this preference on.
6. Return to **Demo controls** to confirm the three available unit hooks and the
   one labelled insufficient-cohort hook. Use the direct **Tasks and CPD**,
   **Progress Burndown**, and **Notifications** links for the other walkthroughs.

All runtime walkthrough values and dynamic routes come from the guarded API
registry. Production sets `enableDemoTools` to false, and even a development web
build does not expose the controls unless the guarded endpoint succeeds for the
authenticated synthetic account. Production therefore cannot activate a
fabricated preview or substitute it for live data.

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
