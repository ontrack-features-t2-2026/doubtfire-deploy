# Demo handover — notifications

> **Historical frozen demo.** Keep this record for provenance only. The
> supported, disposable CPD/PPI/email/push walkthrough is now
> `development/all-features-demo/README.md`, using the exact revisions in
> `HANDOVER.md`. Do not follow the branches, ports or readiness claims below for
> the final handover.

Everything needed to run the Monday demo, for whoever is presenting.

One branch per repo, all called `demo/notifications`. It carries the whole
notification feature: email delivery, the mail catcher, push storage, push
delivery, the service worker, and the push opt-in button.

**Treat it as frozen.** It is a snapshot for the demo, not somewhere to work.
Review happens on the individual `email/*` and `push/*` branches, which may be
rebased. `demo/notifications` will not follow them, and that is the point.

---

## Setup

All three repos must sit side by side in one folder with their original names.
The compose file hardcodes `../../doubtfire-api` and `../../doubtfire-web`.

    ontrack/
      doubtfire-deploy/
      doubtfire-api/
      doubtfire-web/

Same branch in all three:

    cd ontrack/doubtfire-api    && git fetch origin && git checkout demo/notifications
    cd ../doubtfire-web         && git fetch origin && git checkout demo/notifications
    cd ../doubtfire-deploy      && git fetch origin && git checkout demo/notifications

Then, from `doubtfire-deploy/development`:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build

**`--build` is not optional.** This branch adds the `web-push` gem, and a
container built from the old image crash-loops with "Could not find
web-push-3.0.0 in locally installed gems". Both `-f` flags are required on every
compose command.

First time only, or if the database looks wrong:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml run --rm doubtfire-api \
      bash -c "bundle exec rake db:populate"

## Check it before you present

From `doubtfire-deploy/development`:

    bash verify-notifications.sh

Nine sections, every one should say PASS. It checks the containers, the ports,
the web-to-api proxy, mail routing, the push api, the VAPID keys, the service
worker, and it posts a real comment and confirms a real email arrives.

If anything fails, `RUNNING-LOCALLY.md` next to this file has the fixes.

## Addresses

| | |
|---|---|
| Web app | http://localhost:4200 |
| Mail inbox | http://localhost:8025 |
| API docs | http://localhost:3000/api/docs |

Every account's password is `password`.

| Account | Role | Use for |
|---|---|---|
| `acain` | Admin, convenor of COS10001 | the staff side |
| `student_1` | student, project 2 in COS10001 | the student side |

Sign in as one in a normal window and the other in a private window. Most of this
feature is one person doing something and another person being told about it.

Do not use `atutor` — it teaches COS20007, not COS10001, so it cannot see the
task this demo uses.

---

## The demo

### 1. Email on a new comment

1. As `acain`, open COS10001, project 2, task **1.1P**, and post a comment.
2. Open http://localhost:8025. The email is there within a second.
3. Open it and point out that **the comment text is not in the email.** The email
   says who commented and on what, and links back to OnTrack. Content stays in
   the system.

### 2. It respects the user's preference

1. As `student_1`, open the profile and untick **Receive notifications for new
   messages**. Save.
2. As `acain`, comment again.
3. No new mail. One preference switch gates every channel — in-app, email and
   push — rather than each one having its own setting.
4. Turn it back on.

### 3. It works in both directions

As `student_1`, reply. `acain` gets the email. The recipient is always the other
party, never the person who commented.

### 4. Push

1. As `student_1`, open the profile page and **wait about six seconds**. The push
   button is disabled until the service worker registers and says why.
2. Click **Turn on push notifications on this device** and accept the browser
   prompt.
3. Confirm it stored:

       docker exec doubtfire-api bundle exec rails runner \
         'puts PushSubscription.all.map { |s| "#{s.user.username} #{s.endpoint[0,50]}" }'

4. As `acain`, post a comment. A desktop notification appears, and the email
   arrives at the same time.

The point worth making: **push needed no per-event work.** The comment event was
written before push existed. Everything fans out through one service, so the day
push was added, every existing event gained it.

---

## Things that will trip you up

**Do not run `rails test` while presenting.** The test suite and the app share
one database, so tests hold locks that make the app return 500s, and they change
the seeded data.

**Do not post the same comment text twice.** OnTrack drops a comment identical to
the previous one on that task and answers 403. No comment, no email, and nothing
on screen explains it. Vary the text.

**Nothing pushes to a user with no subscription.** That is a silent no-op and
looks exactly like push being broken. Step 4.2 must happen first, in the same
browser you expect the notification in.

**macOS must allow notifications from your browser** in System Settings, or step
4.4 produces nothing with no error anywhere.

### The push says it sent but nothing appears on screen

This is the most likely thing to go wrong, because every layer fails silently.
Work through it in this order — the first check splits the problem in half.

**1. Is it the browser and the operating system, or is it us?** In the dev tools
console on http://localhost:4200:

```js
const reg = await navigator.serviceWorker.ready;
await reg.showNotification('OnTrack', {body: 'local test, no server involved'});
```

- **Nothing appears** — the problem is macOS or the browser, not this feature.
  Go to System Settings → Notifications → your browser, turn **Allow
  notifications** on, and set the alert style to Banners or Alerts rather than
  None. Turn off Do Not Disturb and any Focus mode. Then run the snippet again.
- **It appears** — the browser and the OS are fine, so the problem is between
  the api and the browser. Carry on below.

**2. Is a subscription stored, and for the person receiving the notification?**

    docker exec doubtfire-api bundle exec rails runner \
      'puts PushSubscription.all.map { |s| "#{s.user.username} #{s.endpoint[0,50]}" }'

Empty means the opt-in did not save. Subscribing as one account and triggering a
notification for another is the usual mistake: the push goes to whoever the
notification is *for*, so subscribe as `student_1` and comment as `acain`.

**3. Did the api actually try to send?**

    docker logs --since 5m doubtfire-api | grep -i "push"

`Failed to push to subscription` tells you why. **No line at all** means it never
tried, which means either no subscription for that user or no VAPID keys.

**4. Is the service worker the one you think it is?** Dev tools → Application →
Service Workers. If it says "waiting to activate", or lists more than one, click
**Unregister**, reload, wait six seconds, and subscribe again. A stale worker
from an earlier build accepts the subscription and then does nothing useful with
it.

**Push needs a secure context.** `http://localhost` counts. A phone pointed at
your laptop over the LAN does not, and push will silently fail.

**Clear the inbox before you start** so the demo is not full of test mail:

    curl -s -X DELETE http://localhost:8025/api/v1/messages

---

## What to say if asked

**"Do real emails get sent?"** Not in development. Mailpit is a mail catcher: it
speaks real SMTP, accepts everything and forwards nothing. Production sends over
real SMTP through the same code path.

**"Is that a real email address?"** The seed data uses fake addresses, and two of
the accounts were pointed at a real Deakin address during development to prove
delivery. Mailpit catches it either way.

**"How does a user turn push on?"** The button in the profile. It asks the
browser for permission and stores the registration against that user. One row per
browser, so signing in on a second machine adds a second one.

**"What happens when someone clears their browser data?"** The push service
starts returning 410 for that endpoint, and the api deletes the row the first
time it sees one. Dead registrations do not accumulate.

**"What is left to do?"** Clicking a push notification does not navigate anywhere
yet — the link is in the payload, but reading it needs MN-C03. There is no
in-app notification bell yet either. The rest of the event tickets are written
and unblocked: adding one is now a service call plus two email templates, with no
changes to any shared file.
