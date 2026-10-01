# OnTrack public demo on a Windows PC

This package runs a public OnTrack demonstration with made-up students, units,
submitted work, feedback and Unit Hub content. Anyone with its website address
can use the shared accounts. All email is captured privately on the host PC.

The package includes the latest tested UX candidate, including the student
attention view, separate email/push choices, staff summaries, notification
filters and calendar improvements. The candidate PRs are still separate from
the repositories' default branches. `sources.lock.json` records the exact API,
web and JPlag viewer revisions used by the launcher; it does not follow a moving
branch while installing.

## Open a temporary website first

1. Install and open [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/).
   Use its **WSL 2** option and **Linux containers**. Accept a Windows restart if
   Docker asks for one. You do not need to install an Ubuntu distribution, Git,
   Ruby or Node yourself.
2. Extract the complete OnTrack package into `C:\OnTrack`. Keep it outside
   OneDrive or other synced folders; a short path avoids Windows filename limits.
3. Open **Start OnTrack.cmd** and select **Set up / open temporary website**.
   The launcher is available in both the main folder and the `public-demo` folder.
   The first run downloads the pinned source files, builds the application and
   document tools, creates private settings, and prepares the sample data.
   Downloads and the first build can take a while; later starts reuse them.
4. Open the temporary `https://…trycloudflare.com` address printed by the
   launcher. Share that address with people trying the demo.

A temporary website needs no DNS change or Cloudflare account. Its address can
change when its connector is recreated, so use it for the first demonstration.
Cloudflare describes Quick Tunnels as a testing service; it has a limit of 200
in-flight requests and does not support Server-Sent Events.
[Quick Tunnel limits](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/do-more-with-tunnels/trycloudflare/).

Keep Windows awake and Docker Desktop running while the website is in use.
Closing the launcher window does not stop the containers. Turning the PC off,
sleeping, or losing its internet connection makes the website unavailable.
Enable Docker Desktop's option to start when you sign in to Windows if you
want the permanent demo to restart after signing in. A temporary address needs
the launcher again after a restart; it is not a permanent hosting service.

## Sign in and try it

Every listed account uses password **password**. These shared accounts belong
only to this disposable synthetic demonstration.

| Login | What it can demonstrate |
| --- | --- |
| `student_1` | Student dashboard, task work, feedback, notifications and calendars |
| `staff_1` | Tutor task inbox and feedback for an assigned tutorial |
| `staff_2` | A second tutor's assigned tutorial |
| `chair_1` | Unit chair tools for the sample units |
| `student_2` to `student_25` | Other synthetic students and peer progress |

There is no shared administrator account. Visitors share these accounts and
their changes, so do not enter real names, marks, passwords or private files.
The sample records are real application data, rather than a browser overlay;
the production web build keeps the development-only **Demo controls** hidden.

Useful checks are to submit a small document, view its generated PDF, leave
feedback as a tutor, check the student's notification inbox, and create a
sample unit announcement or class session as the unit chair. Notification
settings control which messages go to the local mail catcher and browser push.
Browser push still requires each person's permission and a successful device
registration. Use the permanent website for installed-app testing and calendar
subscriptions: changing the hostname creates a different browser origin.

Email appears at [the private mail viewer](http://127.0.0.1:8025) **on the host
PC only**. It is not delivered to Microsoft 365 or any other outside mailbox,
even if a visitor changes an account's email address. The public tunnel routes
only to OnTrack and cannot open the mail viewer. Both Rails mail and scheduled
command-line mail use this internal catcher.

## Connect ontrack.maplefox.au later

The temporary website lets you test immediately. For a stable address, create
a named Cloudflare Tunnel and publish **ontrack.maplefox.au** with service type
**HTTP** and service URL **proxy:80**. The connector runs in Docker, so its
origin is `http://proxy:80`, not `localhost:8080`.

Copy the tunnel token from Cloudflare, select **Connect permanent website** in
the launcher, and paste the token when asked. The launcher saves it in the
private, ignored `secrets/tunnel-token.txt`; the container reads the file rather
than putting the token in its command or environment. Do not share that file
or the generated `.env` file.

With Cloudflare's Free plan, the domain's authoritative DNS needs to be on
Cloudflare. Registration can remain at VentraIP. Before changing nameservers,
save **every existing DNS record** and recreate it on Cloudflare, including any
VentraIP mail records and any Microsoft records actually in use. Cloudflare's
automatic scan can miss records. Do not replace existing mail records merely
because a Microsoft 365 subscription is available. The domain can continue
using its current email provider.

Only change VentraIP nameservers after checking the replacement zone. VentraIP
warns that changing nameservers can remove its existing DNS records. DNS
changes take time; the temporary demo remains an option while the permanent
address is being prepared. These account-side steps are not performed by the
launcher. See [Cloudflare Tunnel setup](https://developers.cloudflare.com/tunnel/get-started/),
[Cloudflare full DNS setup](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/)
and [VentraIP's nameserver guide](https://ventraip.com.au/support-centre/modifying-the-nameservers-on-a-domain-name-registration/).

Microsoft Entra sign-in is not needed for these intentionally shared demo
accounts. This package leaves real Teams imports, Turnitin and Overseer off;
those integrations require their own approved services and credentials. The
unit calendar, announcements, manual Teams links and regular OnTrack workflows
still work without those connections.

## Daily use

- **Check status** shows the containers, including the active website connector.
- **Stop** stops this demo and keeps its data.
- **Set up / open temporary website** starts it again. Ordinary starts preserve
  visitor changes; they do not reset the dataset.
- **Reset demo data** removes only this demo's containers and named volumes
  after the explicit `RESET DEMO` confirmation, then rebuilds the sample data.
  This removes submissions, messages, notifications and captured mail from the
  demo. It does not remove another OnTrack project's data.

The local origin is [http://127.0.0.1:8080](http://127.0.0.1:8080), useful for
checking whether the app works before the public connection is ready. Prefer
the printed HTTPS website when testing sign-in persistence, push and PWA
features. Ports 8080 and 8025 listen only on the PC's loopback address. Database,
Redis, SMTP and document-helper ports are not published.

The complete stack includes MariaDB, Redis, the static web app, production
Rails, a Sidekiq worker consuming **mailers, notifications, submissions and
default**, the scheduled PDF/portfolio process, two isolated TeX Live helpers,
JPlag and a restricted Docker API proxy. This is more complete than the older
local notification demo, which intentionally leaves general work queues idle.

The database and all changing application data use Docker named volumes, so
they do not depend on Windows filesystem database semantics. Source folders
are build inputs only. On a 64 GB PC, allowing Docker around 24–32 GB leaves
room for both the stack and Windows; start with the defaults and measure actual
usage. TeX and JPlag have explicit CPU, memory and process limits.

Uploads are capped at **95 MB per HTTP request**, including multipart overhead.
Individual OnTrack fields may have smaller limits. This fits below Cloudflare's
100 MB Free/Pro request limit. A document conversion continues in the worker
after the upload; the browser does not need to hold one request open for it.
[Cloudflare upload limits](https://developers.cloudflare.com/support/troubleshooting/http-status-codes/4xx-client-error/error-413/).

Only one stack using the inherited `jplag` container name can run on the same
Docker engine. Stop an older OnTrack stack if that name is already taken; the
launcher must not delete an unrelated container to claim it.

## Maintainer checks

This directory is separate from the institutional `production/` deployment.
It does not relax the institutional validator or its external-identity
requirement. The public seed checks production Rails, the explicit
`public-demo` profile, both configured and connected database names, database
authentication, and the private SMTP destination before writing data.

After extracting or checking out the pinned API and web sources, a maintainer
can use the same Compose file directly. Use a generated `.env` for startup;
`.env.example` contains unusable placeholders and is only for configuration
checks. The ordered first startup is:

```text
docker compose --env-file .env -f compose.yml build
docker compose --env-file .env -f compose.yml up -d --wait db redis mailpit
docker compose --env-file .env -f compose.yml --profile setup run --rm bootstrap
docker compose --env-file .env -f compose.yml up -d --wait --wait-timeout 300
docker compose --env-file .env -f compose.yml --profile setup run --rm bootstrap bundle exec rake db:public_demo_verify
```

The Windows launcher also handles source checks, fresh application secrets,
VAPID generation and the public hostname. All generated secrets persist across
ordinary starts. Local QA may set `DF_PUBLIC_DEMO_API_PATH` and
`DF_PUBLIC_DEMO_WEB_PATH` to full source directories; shared release packages
use their exact downloaded source revisions.

To check the deployment contract without starting anything, resolve **all**
profiles to JSON and pass that file to `compose_contract_test.py`:

```text
docker compose --env-file .env.example -f compose.yml --profile setup --profile tunnel --profile quick config --format json
python3 compose_contract_test.py compose.resolved.json
```

Save the first command's output as UTF-8 `compose.resolved.json`. The test checks
loopback-only ports, private mail, shared storage, production runtime,
complete worker configuration, offline constrained helpers, secret-file tunnel
credentials and the restricted Docker socket mount. Follow it with live checks
of sign-in, a submission-to-PDF round trip, feedback, captured email, the
notification filters and a calendar feed through the chosen HTTPS website.

After building the proxy image, `python3 proxy_smoke_test.py` also checks the
actual Nginx upload rejection and response headers. It uses a temporary
loopback-only container and removes that container when finished.
