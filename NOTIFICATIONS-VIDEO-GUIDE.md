# EN + MN visual feature recording guide

This script covers user-visible Email Notifications (EN) and Mobile
Notifications (MN) behavior only. Do not show source code, API routes, database
records, worker queues, logs, automated tests, or internal VAPID details.

## Truth checks before recording

- This is an installable web app with Web Push, not a native mobile app.
- Every runtime email currently has the subject `OnTrack: New notification`.
  Event-specific subjects in copy guidance are not implemented.
- Task, feedback, and portfolio switches gate in-app, email, and push together.
  General and extension notifications are always delivered.
- EN-V08 is conditional on product approval. The implementation is an audio
  discussion request (`discussion_request_created`), not a booked appointment.
- MN-Q01 desktop and MN-Q02 Android verification are still blocked. Record fresh
  browser/device evidence and name the exact browser and OS; do not claim broad
  compatibility from the existing evidence.
- iOS/iPadOS push requires 16.4 or later and an installed Home Screen web app.

## Prepare before pressing Record

Use synthetic data only.

1. Open three windows:
   - Student A in a normal browser profile.
   - Tutor/Convenor A in a second browser profile or private window.
   - Mailpit at `http://localhost:8025`, with the inbox cleared.
2. Give Student A all three notification preferences and a desktop push
   subscription. Give Tutor A task notifications and a separate subscription.
3. Prepare Student B with no notifications for the empty-state shot.
4. Prepare one active unit with:
   - two visibly different tutorials;
   - group work and at least one group;
   - a task Student A can submit for feedback;
   - an incomplete task due within three days;
   - an editable existing task and a new task ready to publish;
   - a pending extension request;
   - portfolio prerequisites already satisfied.
5. Seed at least 21 synthetic notifications across feedback, task, portfolio,
   extension, and general categories so pagination is visible.
6. Reset browser notification permission to **Ask**, enable OS notifications,
   disable Focus/Do Not Disturb, and keep a second profile with permission
   deliberately blocked.
7. Uninstall the existing PWA and clear `ontrack_pwa_install_dismissed` before
   the install scene. Prepare frontend version A and a newer version B for the
   update prompt.
8. Confirm the worker is running and that email reaches Mailpit. For phone
   footage, use an HTTPS host; a plain HTTP LAN address is not a secure context.

## Recording order

### 1. Opening — 10 seconds

Show the signed-in student dashboard and say:

> This recording demonstrates the user-facing Email Notifications and Mobile
> Notifications features in OnTrack: preferences, the notification centre,
> rendered emails, Web Push, and install/update prompts. It does not cover API
> or backend implementation.

### 2. Notification preferences and per-device push — 60–90 seconds

Student A: open **My Profile** (`/edit_profile`) and show the **Notification
Settings** section:

- Task notifications
- Feedback notifications
- Portfolio notifications

Then record this exact flow:

1. Turn **Task notifications** off and click **Save Profile**.
2. Reopen the profile and show the switch remained off.
3. In the actor window, trigger a task event. Return to Student A and show there
   is no badge, email, or push.
4. Turn the switch back on, save, trigger again, and show delivery.
5. After a clean reload, briefly capture the disabled push control and the text:
   `Still starting up. This becomes available a few seconds after the page loads.`
6. Click **Turn on push notifications on this device** and accept the native
   browser prompt.
7. Show the snackbar `Push notifications turned on`, the button changing to
   **Turn off push notifications on this device**, and the hint
   `This device will receive push notifications.`
8. Turn push off once and capture `Push notifications turned off`; enable it
   again for later scenes.

In the denied-permission profile, show the disabled control and:

`You have blocked notifications for this site. Allow them in your browser settings, then reload.`

Also show the displayed browser recovery steps.

### 3. PWA install and update prompts — 45–60 seconds

Install scene:

1. Open the app in a clean, installable desktop profile.
2. Show `Install OnTrack for quicker access and notifications` with **Install**.
3. Click **Install**, complete the browser-native prompt, and show the standalone
   OnTrack window and app icon.
4. Reload in standalone mode and show the install prompt does not repeat.

For iOS footage, show the guidance:

`To install OnTrack: tap Share then "Add to Home Screen"`

Update scene:

1. Load version A, then make version B available.
2. Show the persistent message
   `A new version of OnTrack is ready. Reload to update now.` with **Reload**.
3. Click **Reload** and visibly confirm version B loaded.
4. Optional: show
   `This version of OnTrack can no longer run safely. Reload to recover.`

### 4. Desktop notification centre — 60–90 seconds

On any signed-in desktop page:

1. Show the header bell and unread badge.
2. Open the dropdown and show its **Notifications** heading, newest five rows,
   relative timestamps, delete controls, **Mark all read**, and
   **See all notifications**.
3. Point out bold text and blue dots for unread items.
4. Show all five category treatments:
   - feedback — blue chat bubble;
   - task — amber assignment;
   - portfolio — purple portfolio;
   - extension — green time;
   - general — grey campaign.
5. Click an unread task notification. Show the intended task/project page opens
   and the unread count decreases.
6. Delete one row, confirm the permanent-delete prompt, and show
   `Notification deleted`.
7. Click **Mark all read** and show badge/dots clear.
8. Click **See all notifications**.

### 5. Full page, pagination, mobile layout, and empty states — 60 seconds

On `/notifications`:

1. Show the chronological list with the same icons, colors, unread states, and
   timestamps as the dropdown.
2. Show page-size choices 10, 20, and 50; leave 20 selected and move to page 2.
3. Use **Mark all read** and delete one row.
4. With Student B, show:
   - `You have no notifications yet.`
   - `Comments on your tasks, feedback and reminders will show up here.`
5. Optionally show the dropdown empty state:
   - `You are all caught up.`
   - `Anything new will show up here.`
6. Resize below 600 px. Show the desktop bell disappears, then open the account
   menu and show **Notifications** with its unread count.
7. Open the responsive page and show **Mark all read** reducing to its icon while
   remaining usable.

### 6. Complete EN event showcase

For each event, keep the same visual rhythm:

1. Show the actor's on-screen action.
2. Cut to the recipient's in-app row or OS push.
3. Open the matching Mailpit message and show its recipient, generic subject,
   event-specific body, privacy-safe omissions, and link.

#### EN-E01 — task comment created

- Tutor: open Student A's task, type in the `Aa` composer, and press Enter.
- Student result: `Tutor Name commented on TASK in UNIT.` with feedback styling.
- Show that email omits the actual comment text and the link opens the task.

#### EN-E02 — task status changed

- Tutor: use a visible status action such as **Mark as Complete**, **Mark as
  Redo**, or **Mark as Resubmit**.
- Student result: `Tutor Name updated the status of TASK in UNIT.`
- Show that email/push deliberately omit the new status value.

#### EN-E03 — extension assessed

- Tutor: open a pending extension comment and click **Grant** or **Deny**.
- Student result: `Extension granted to ...` or `Extension rejected`.
- If possible, use two prepared requests and show both outcomes.

#### EN-V01 — task due date changed

- Convenor: **Unit Administration → Tasks**, edit an existing task's due dates,
  then click the floating save button.
- Student result: `The due date for TASK in UNIT has changed.`
- Show that the email says the new date is not included.

#### EN-V02 — new task available

- Convenor: **Unit Administration → Tasks → Add Task**, create an immediately
  available eligible task, and save.
- Student result: `A new task is available: TASK in UNIT.`
- Open the notification link and show the new task.

#### EN-V03 — task due soon

- Prepare an incomplete eligible task due within three days and run the
  scheduled reminder before filming; there is no useful on-camera actor action.
- Student result: `TASK in UNIT is due soon.`
- Show that the email omits the actual deadline.

#### EN-V04 — tutorial changed

- Convenor: **Unit Administration → Students**, find Student A, and change their
  existing tutorial.
- Student result: in-app/email name the new tutorial, unit, day, and time while
  omitting the old tutorial. Push says `Your tutorial details changed.`

#### EN-V05 — group membership changed

- Tutor/Convenor: open **Unit Groups**, choose a group, and add Student A with
  member autocomplete. Optionally remove the student with the trash icon.
- Student result: the in-app/email message names the group and says added or
  removed. Push says `Your group membership changed.`

#### EN-V06 — task submitted

- Student A: open a task and change it to **Ready for Feedback**.
- Tutor result: in-app/email name the student and task but omit submission
  content. Push says `A task is ready for marking.`

#### EN-V07 — portfolio received

- Student A: open **Create Portfolio**, reach **Review Portfolio**, and click
  **Create My Portfolio**.
- Student result: a timestamped receipt. Show the email says this confirms
  receipt, not an assessment outcome. Push says
  `Your portfolio submission was received.`

#### EN-V08 — discussion request (conditional)

Only record this after product approval of the rescope.

- Tutor: open Student A's task, choose **Create discussion prompts**, add/record
  a prompt, and click **Send discussion prompts**.
- Student result: `A discussion prompt is ready for you.`
- Show that email excludes audio/prompt content and the link opens the task.
- Do not say that a discussion was booked.

### 7. Push privacy and interaction montage — 60–90 seconds

Show OS banners titled **OnTrack** using the implemented v2 bodies:

- `The due date for TASK in UNIT has changed.`
- `A new task is available: TASK in UNIT.`
- `TASK in UNIT is due soon.`
- `Your tutorial details changed.`
- `Your group membership changed.`
- `A task is ready for marking.`
- `Your portfolio submission was received.`
- `A discussion prompt is ready for you.` (only if EN-V08 is approved)

Briefly compare tutorial, group, task-submitted, and portfolio lock-screen text
with the richer authenticated in-app/email content. This is the clearest visual
demonstration of MN-S04 privacy behavior.

Then record:

1. **Safe click-through** — leave the recipient tab unfocused, trigger a real
   task comment, click the OS banner, and show OnTrack focuses directly on the
   intended `/projects/<id>/dashboard/<task>` route.
2. **Burst collapse** — post three quick comments to the same task. Show only
   one OS banner remains with the newest body, while the in-app centre and
   Mailpit retain individual notifications.
3. **Sign-out cleanup** — sign out Student A, trigger another event, and show no
   push arrives in that browser. Sign in as Student B and show Student A's
   subscription is not reused.

Do not try to force subscription rotation on camera; browsers do not expose a
reliable visual trigger for MN-C05.

### 8. Closing — 10 seconds

End on the full notifications page and say:

> OnTrack now gives users one consistent notification experience across the
> in-app centre, email, and privacy-safe Web Push, with user-controlled
> categories and install/update support for the PWA.

## Leave out of the recording

- API endpoints, database tables, migrations, VAPID internals, queues, logs,
  source code, automated tests, and security-review documents.
- Subscription-rotation internals, offline documentation, and support matrices.
- Claims of Chrome, Edge, Firefox, Android, or iOS parity without fresh evidence.
- Event-specific email subjects.
- Any claim that this is a native app.
- Any claim that EN-V08 is a completed booking feature without explicit product
  approval.

