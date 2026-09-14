# Unit Hub: announcements, HelpHub and online classes

Unit Hub brings a student's current unit announcements and upcoming learning
sessions into OnTrack. Teaching staff assigned to the unit can maintain the
content, add a Teams source link, and publish the correct join link. Access is
checked against current enrolment on the API, including for calendar feeds.

The web application and installed mobile PWA use the same feature. These three
repositories do not contain a separate native iOS or Android application.

## Release and deployment

Use the API and web revisions pinned by this deployment change together. The
API adds `CreateUnitHub` (`20260914000000`), the calendar revision migration
(`20260914000001`) and `AddTeamsAnnouncementSources` (`20260914000002`),
the announcement, learning-session and Teams sync state tables, and an
`include_learning_sessions` calendar preference. Existing
calendar subscriptions start with learning sessions **off**.

1. Build the matching API, worker and web images using the existing release
   process. Use the **production** Angular configuration for the ordinary
   published application; it disables demo tools.
2. Apply the API database migration before starting the new web version. The
   production Compose `migrate` service already enforces this ordering for the
   API service. No additional external service or credential is required for
   staff-authored Unit Hub content.
3. Open **Unit Hub** from OnTrack. Sign in with an assigned teaching-staff
   account, select the intended unit, and add the actual announcement or
   session. Drafts are not shown to students. Schedule recurring HelpHubs as
   weekly sessions with an end date. A Thursday and Friday HelpHub uses two
   weekly schedules so each day's time can be maintained separately.
4. Check with a student enrolled in one unit and not another. The unrelated
   unit must not appear in the feed. Use the read-only smoke check below to
   verify the API boundary.

No screenshot content, real names, or real meeting links are seeded into the
published application. Content comes from unit staff or explicitly approved
Teams publishers when the optional connection below is enabled.

For rollback, revert the web/API image versions and retain the additive database
tables. Do not drop the new tables as a routine rollback: that would remove
staff-authored content. Restore the old images using the existing deployment
procedure and retain a normal database backup.

## Demo walkthrough

The existing **Demo controls** switch enables the synthetic Unit Hub preview in
development. Open **Unit Hub** after enabling it. It demonstrates SIT111
announcements, HelpHub and lecture sessions, and explicitly labelled demo
calendar drafts/downloads. No real meeting is opened from a sample join link. The synthetic
student is not enrolled in SIT102, so SIT102 content is excluded. Demo content
is labelled, is held in the browser only, and cannot be saved through the staff
forms or written to the live API.

Turn Demo mode off to return Unit Hub to the signed-in account's real API data.
An empty unit has an empty state until its staff publish content. The hub's
normal mode reads real authorised content even in a development build; unrelated
older demo features may retain their existing quiet-mode behaviour.

For the supported isolated local stack:

```bash
cd development/all-features-demo
./demo.sh sources
./demo.sh prepare
```

The helper supports `DF_DEMO_API_PATH` and `DF_DEMO_WEB_PATH` when using isolated
checkouts. See [the demo runtime guide](development/all-features-demo/README.md)
for local accounts, ports, shutdown and source selection. Do not use the demo
configuration for the ordinary production build.

The demo Compose overlay explicitly disables Teams import and clears its
tenant, mappings and application credentials, even if values were set elsewhere.
The browser demo uses fictional content and does not connect to Microsoft.

## Calendar choices

- **Google Calendar** opens a one-off event with the session time and join
  link. The student decides whether to save it.
- **Download calendar event** provides an ICS event for other calendar apps.
  One-off additions and imports do not receive later changes automatically.
- The existing **Web Calendar** settings provide an optional subscription.
  Enable learning sessions to include the student's relevant HelpHubs and
  classes, including join links. Unit exclusions still apply. Calendar clients
  refresh subscriptions on their own schedule; check OnTrack before joining if
  a session was recently changed or cancelled.

Google's subscription setup uses a computer browser: **Other calendars → From
URL**. Once added to the same Google account, the calendar is available on its
mobile devices. A deployed HTTPS feed must be reachable by Google; a localhost
demo feed cannot be fetched by Google's servers. Treat the private subscription
URL like a password, and use the existing reset/disable controls if it is shared.

References: [Google calendar subscriptions](https://support.google.com/calendar/answer/37100?hl=en)
and [ICS imports](https://support.google.com/calendar/answer/37118?hl=en).

## Existing Entra SSO and optional automatic Teams announcements

Keep the deployment's existing SSO configuration. Signing in identifies the
OnTrack user; OnTrack enrolment determines the units they see. That sign-in does
not by itself grant permission to read Teams messages. The optional connection
uses a university-managed Microsoft application, so students and teaching staff
do not need another personal sign-in or a separate account-linking step.

Before enabling the connection, the university administrator must approve the
source channels and data use, register a single-tenant Microsoft application,
and grant the required Graph permission. Prefer resource-specific
`ChannelMessage.Read.Group` consent for the approved teams, using the
university-approved Teams app installation/consent process. Broader
`ChannelMessage.Read.All` access requires a separate deliberate administrative
decision. The importer uses Microsoft public-cloud endpoints.
See [Microsoft's channel message permissions](https://learn.microsoft.com/en-us/graph/api/channel-list-messages?view=graph-rest-1.0)
and [resource-specific consent](https://learn.microsoft.com/en-us/microsoftteams/platform/graph-api/rsc/resource-specific-consent).

Map an exact **unit offering database ID**, team ID and student-wide
General/announcements channel ID. Do not infer mappings from matching unit codes,
display names or email addresses. Never map a private staff channel: OnTrack
enrolment is not proof of Teams channel membership. Set `student_visible:true`
only after checking that every student enrolled in that offering is entitled to
see its content. Supply an allowlist of approved staff publisher Entra object
IDs; other users' messages, replies and system/application posts are excluded.

Put these settings in the protected production environment file (mode 0600),
populated through the deployment's normal secret-management process:

```dotenv
DF_TEAMS_ANNOUNCEMENTS_ENABLED=true
DF_TEAMS_TENANT_ID=<university-tenant-guid>
DF_TEAMS_CLIENT_ID=<approved-application-guid>
DF_TEAMS_CLIENT_SECRET=<application-secret>
DF_TEAMS_CHANNEL_MAPPINGS=[{"unit_id":123,"team_id":"<team-guid>","channel_id":"19:<channel-id>@thread.tacv2","publisher_ids":["<staff-object-guid>"],"student_visible":true}]
```

Replace every placeholder with administrator-verified values. Keep the JSON on
one line without surrounding quotes. Install Python 3 on the deployment host
for the optional mapping validation. The production validator rejects missing
credentials, malformed mappings, missing publisher allowlists and channels without
the explicit visibility declaration. At most 20 mappings are supported. The
API and main worker receive the tenant and mapping metadata; only the main
worker receives the client ID and secret. No Microsoft credential goes to the
web application, PDF worker or migration service.

Validate and deploy through the existing production process. To check the
connection immediately after deployment, run in the main worker:

```bash
production/compose.sh exec sidekiq bundle exec rake teams:sync_announcements
```

The background worker checks every five minutes. The Unit Hub's configured
label means that an approved mapping exists; it is not proof that Microsoft
consent or the last sync succeeded. Verify a real approved staff post appears
for an enrolled test student, edit it in Teams and verify the updated copy,
then delete the test post and check that its copy is removed. Also test an
unapproved publisher and a student from another unit. No such live tenant test
can be completed without the university connection.

Imported posts show **From Teams** with a source link and are maintained in
Teams. Content is converted to plain text; attachments remain in Teams. The
importer updates existing copies using stable source IDs. Each run reads up to
100 recent root messages per mapping and revisits up to 25 older imported
messages. An explicit deleted/not-found result hides a copy; absence from a
limited page never counts as deletion. Older messages that have never been
imported are outside this bounded initial import.

Removing/changing a mapping, changing its tenant or approved publishers, or
disabling the feature hides its previous copies immediately on subsequent
requests. Apply metadata changes to both API and worker together. A confirmed
Microsoft access refusal hides affected copies; transient outages retain
previously verified copies for at most seven days. Provider throttling is
respected across worker runs. After publisher-policy changes, previously
imported posts from the same source channel are revisited in bounded batches
and only still-approved content becomes visible again. Changing the unit,
tenant or channel establishes a different source identity.
The API handover documents the exact bounds and operator sync-state fields.

HelpHub and class schedules remain maintained by assigned teaching staff in
OnTrack, with the real Teams meeting join URL. Free-form posts are not parsed
into class times. Automatic timetable import requires a separately approved,
authoritative schedule source; existing SSO alone cannot supply that schedule.

## Read-only deployment smoke check

Use a dedicated student test account enrolled in the expected unit only. Set
`UNIT_HUB_USERNAME` and `UNIT_HUB_AUTH_TOKEN` in a private terminal session using
the deployment's normal secret-handling process. Do not paste tokens into issue
comments or commit them. Unit IDs are database IDs, not unit codes.

```bash
python3 development/verify-unit-hub.py https://your-ontrack-host \
  --expected-unit-id 111 --excluded-unit-id 102
```

The IDs above are placeholders. The script requires sign-in, checks feed unit
boundaries and cache headers, and verifies the student cannot read staff drafts
for either unit. It performs GET requests only, rejects redirects and does not
print credentials, announcement bodies or meeting links. Follow with the staff
publish/edit/cancel journey, calendar opt-in and mobile layout checks described
in the web and API handover documents.
