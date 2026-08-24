# Removable all-features demo

This folder owns the local CPD, PPI, email-notification, in-app-notification,
and mobile/push demonstration runtime. It deliberately does not reuse the
older `notifications-demo` database, Redis state, student work, temporary
files, or Node dependencies.

The matching API scenario is deterministic and development-only. It creates
generic `demo_*` accounts with `.invalid` email addresses, a real 40% anonymous
peer cohort, cross-unit tasks with useful deadline states, and a small curated
notification set. It never creates a browser push subscription.

## Start and populate

This demo uses the familiar ports 4400, 3200, and 8225. Stop any older local
stack using those ports before starting it. Stopping the older stack is enough;
do not remove its volumes.

From this folder:

```bash
./demo.sh start
./demo.sh seed
```

The database has a readiness check, so the API and worker wait for a fresh
MariaDB instance rather than racing it. The seed action applies migrations,
installs the API's standard roles and task states, then recreates the
deterministic demo records. It is safe to run again whenever the scenario needs
to be reset.

Then open:

- OnTrack: <http://localhost:4400>
- API: <http://localhost:3200>
- Mailpit: <http://localhost:8225>

Sign in as `demo_student` with password `password`. The web account menu links
to **Demo controls**, where the local demonstration data can be turned on and
off. The switch does not grant browser notification permission or create a
push subscription.

To build from isolated worktrees instead of the normal sibling checkouts:

```bash
DF_DEMO_API_PATH=/absolute/path/to/api-worktree \
DF_DEMO_WEB_PATH=/absolute/path/to/web-worktree \
./demo.sh start
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
