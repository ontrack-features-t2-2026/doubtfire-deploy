# Running OnTrack locally (web and api)

How to run OnTrack on your computer with Docker. It also lists the problems we hit and how
to fix them.

## What runs

- doubtfire-api: the backend (Rails). Port 3000.
- doubtfire-sidekiq: the background worker that processes queued jobs from Redis.
- doubtfire-web: the frontend (Angular). Port 4200.
- Mailpit: catches every email the app sends. Web inbox on port 8025.
- A database (MariaDB) and Redis. Docker starts these for you.

## Before you start

- Install Docker Desktop and start it.
- Set your git remotes. `origin` is the team org, `upstream` is thoth-tech.
- Do not use the `development` branch. It is old and frozen.
- Do not install Ruby or Node. They run inside the Docker images. The api needs Ruby 3.4.
  The web needs Node 22.22.3 or newer.
- Do not run `rails`, `rubocop`, or `bundle` on your own computer. Your Mac has old Ruby
  (2.6). Run those inside the container instead.

## Clone all three repos side by side

This is the most common reason the build fails.

Docker builds the api and web containers from folders it expects to find next to the deploy
folder. The compose file hardcodes `../../doubtfire-api` and `../../doubtfire-web`. If your
folders have different names, or are nested, or you only cloned the deploy repo, the build
fails and the error will not tell you why.

Make one parent folder and clone all three into it:

    mkdir ontrack && cd ontrack
    git clone https://github.com/ontrack-features-t2-2026/doubtfire-deploy.git
    git clone https://github.com/ontrack-features-t2-2026/doubtfire-api.git
    git clone https://github.com/ontrack-features-t2-2026/doubtfire-web.git

You should end up with exactly this:

    ontrack/
      doubtfire-deploy/
      doubtfire-api/
      doubtfire-web/

Do not rename the folders. Do not put doubtfire-api inside doubtfire-deploy. The deploy repo
already has empty folders with those names. They are uninitialised submodules. Your code
does not go there.

## Which branch to check out

- **doubtfire-api** and **doubtfire-web**: `feature/notifications`, or your own work branch
  made from it.
- **doubtfire-deploy**: `11.0.x`.
- **Peer Progress Indicator work**: use `ppi/student-progress-endpoint` for
  **doubtfire-api** while API PR #16 is open. After it merges, use
  `feature/peer-progress-indicator`. Use `feature/peer-progress-indicator` for
  **doubtfire-web**.

If `development/docker-compose.local-paths.yml` is not in your checkout, you are on the
wrong branch, or the fix has not been merged yet. Ask the lead.

The api and web containers run whatever is checked out in those sibling folders, including
changes you have not committed. So the branch you pick is the code you are running.

## Steps to run

All commands run from the deploy folder:

    cd doubtfire-deploy/development

**Use both `-f` flags on every command.** The second file is what points the build at your
sibling folders and fixes the api proxy. Without it nothing works.

**Do not run `run-api-web.sh`.** It sits in this folder and looks like the way to start
things. It leaves out the second `-f` flag and fails on an empty build context.

1. Build and start everything. Use `--build` the first time, and after you switch to
   `11.0.x`.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build

   The first build is slow. It installs gems and node packages.

2. Set up the database. Do this the first time, or any time the database is broken.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml run --rm doubtfire-api \
      bash -c "bundle exec rake db:populate"

   `db:populate` already drops, creates, migrates and seeds the database on its own. The
   longer command you may see elsewhere does the slowest part of setup twice.

   If you get a database connection error, the database container is probably still
   starting. Wait a few seconds and run the command again.

   It takes a while and prints a lot. That is normal.

3. Make sure the app is up.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d

4. Open the app.

   - Web: http://localhost:4200
   - API docs: http://localhost:3000/api/docs
   - Mail inbox: http://localhost:8025

5. Log in. Every test user has the password "password".

   - Student: student_1
   - Admin: aadmin
   - Convenor: aconvenor
   - Tutor: atutor

   You will usually want two of these signed in at once, because most notification work is
   one person doing something and another person being told about it. Use a private browser
   window for the second account instead of logging in and out.

   A student's dashboard is at `/projects/<project id>/dashboard`. There is no top-level
   `/dashboard` page. Typing that address sends you back to the home page.

## Where the emails go

**Open http://localhost:8025**

That is Mailpit, a mail catcher. Every email the app sends arrives there and you can read
it in your browser, subject, recipient and all. New mail appears without reloading the page.

The app never sends real email in development. Mailpit accepts everything and forwards
nothing, so you can safely put your own address on a test account.

- Web inbox: http://localhost:8025
- The api sends to it over SMTP on port 1025 inside Docker.

Notification email is queued in Redis instead of sent on the api request path. The
`doubtfire-sidekiq` service reads that queue and delivers the email to Mailpit. The normal
`up` command starts the worker.

Check the worker and its recent job output:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml ps doubtfire-sidekiq
    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml logs --tail 100 doubtfire-sidekiq

Stopping the worker does not lose already queued notification email. Starting it again
processes the pending work:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml stop doubtfire-sidekiq
    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml start doubtfire-sidekiq


If the inbox stays empty:

1. Check the container is running: `docker ps | grep mailpit`
2. Check the api knows about it:

    docker exec doubtfire-api printenv DF_SMTP_ADDRESS

   You want `df-compose-mailpit`. If it is blank, your api container was started before the
   mail catcher was added. Recreate it:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d doubtfire-api

   A plain `restart` is not enough. Environment variables only change on recreate.

**Without Docker**, or if `DF_SMTP_ADDRESS` is unset, the api falls back to writing each
email to a file under `doubtfire-deploy/data/tmp/mails/`. One file per recipient address,
with new mail appended to the end. That is the old behaviour and it still works.

The comment in `doubtfire-api/config/environments/development.rb` used to say mail landed in
`doubtfire-api/tmp/mails`, which was wrong under Docker and sent people looking in an empty
folder in the wrong repository. That comment is now fixed.

## How to check it is working

- See the containers:

    docker ps

- Check the api answers, from inside the container:

    docker exec doubtfire-api curl -s localhost:3000/api/settings

- Check the web can reach the api through its proxy. You want 200:

    docker exec doubtfire-web curl -s -o /dev/null -w "%{http_code}\n" localhost:4200/api/settings

- Check the mail catcher answers. You want 200:

    curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8025/

- List what is in the mail inbox without opening a browser:

    curl -s http://localhost:8025/api/v1/messages | head -c 400

- Read the logs:

    docker logs doubtfire-api
    docker logs doubtfire-sidekiq
    docker logs doubtfire-web

## Asking for help

Grab these before you ask. The second one answers most questions on its own.

    docker ps -a

On macOS or Linux:

    docker logs --tail 200 doubtfire-api > api-log.txt 2>&1
    docker logs --tail 200 doubtfire-web > web-log.txt 2>&1

**On Windows, wrap it in `cmd /c` or the file comes out unreadable.**

    cmd /c "docker logs --tail 200 doubtfire-api > api-log.txt 2>&1"
    cmd /c "docker logs --tail 200 doubtfire-web > web-log.txt 2>&1"

PowerShell does two things to a plain `>` redirect that ruin the file. It writes UTF-16, so
every character comes out with a null byte next to it and most tools see binary rather than
text. And it treats anything the command sends to stderr as a PowerShell error object, so the
real message gets buried under `At line:1 char:1`, `CategoryInfo` and `FullyQualifiedErrorId`
noise, with the actual error split away from its own stack trace. `cmd /c` does neither.

Use `docker ps -a` and not `docker ps`. Plain `docker ps` hides containers that have already
exited, and a container that exited is usually the whole problem. If `doubtfire-api` is
missing from `docker ps` but says Exited in `docker ps -a`, that is your answer and its log
says why.

**Send logs as text, not as a screenshot.** Attach the two files, or paste the output inside
a fenced code block with three backticks. A screenshot of a terminal crops the part that
matters, cannot be searched, and in a Ruby crash the line you need is usually well below the
line you can see. Text can be matched against the errors in the next section in seconds. A
screenshot cannot.

Screenshots are still the right thing for anything visual. "The page says Temporarily
Unavailable" is a screenshot, because the rendering is the evidence. Anything with a stack
trace in it is text.

Say which branch each repo is on as well, and whether you used both `-f` flags. A lot of the
answers below turn on those two things. From `doubtfire-deploy/development`:

    git branch --show-current
    git -C ../../doubtfire-api branch --show-current
    git -C ../../doubtfire-web branch --show-current

## Problems and fixes

1. The api will not start. Error: "Your Ruby version is 3.1.7, but your Gemfile specified
   ~> 3.4.0".
   Cause: the image was built with old Ruby. `11.0.x` needs Ruby 3.4.
   Fix: rebuild the images. Add `--build` to the up command.

2. The web will not start. Error: "The Angular CLI requires a minimum Node.js version of
   v22".
   Cause: the image was built with old Node. `11.0.x` needs Node 22.
   Fix: rebuild the images. Add `--build`.

3. `up` stops straight away. Error: "service overseer-worker-1 has neither an image nor a
   build context".
   Cause: an old local-paths file had overseer services with no image.
   Fix: already fixed. The local-paths file now only has api and web.

4. The web crashes. Error: "Missing script: start-compose".
   Cause: `11.0.x` renamed that script to "start".
   Fix: already fixed. The local-paths file runs "npm start".

5. The api crashes while migrating. Error: "Table 'doubtfire-dev.task_prerequisites' doesn't
   exist".
   Cause: the database has old, half-set-up data. The api container runs `db:migrate` every
   time it starts, so a half-populated database makes it crash on boot over and over, before
   it ever listens on port 3000.
   Fix: reset the database. Run step 2 above.

   **If step 2 fails too, throw the database away and start it again.** Step 2 asks MariaDB
   to drop the database, and a server that cannot read its own files cannot drop them
   either. `-v` deletes the volume the database lives in, which is the only thing that
   clears it.

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.local-paths.yml down -v

   docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d

   docker compose -f docker-compose.yml -f docker-compose.local-paths.yml run --rm doubtfire-api bash -c "bundle exec rake db:populate"
   ```

   MariaDB sets itself up from scratch on first boot, so give it a few seconds after the `up`
   before you run the populate.

   This deletes your local data. That is fine, everything in it came from `db:populate` and
   the command above puts it all back. `-v` also clears the web `node_modules` volume, so the
   next start is slower while npm reinstalls. Your code is untouched either way: the repos
   are bind mounted, not copied.

6. The app loads but shows "Temporarily Unavailable" and the title stays "Loading...".
   **Check the api is running before you read any further.** `docker ps` hides containers
   that have exited, so run `docker ps -a` and look for `doubtfire-api`. If it is missing or
   says Exited, this is not a proxy problem, it is problems 5, 10 or 14, and `docker logs
   doubtfire-api` says which.
   Cause: the web app cannot reach the api. The proxy points at localhost:3000, which is
   wrong inside the container. The api is a different container named doubtfire-api.
   Fix: already fixed. The local-paths file mounts `proxy.conf.docker.json`, which points at
   doubtfire-api:3000. If you still see the error, rebuild the web container and reload:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build doubtfire-web

7. The build fails straight away, or complains about an empty or missing build context.
   Cause: your folders are not laid out the way the compose file expects, or you only cloned
   the deploy repo.
   Fix: see "Clone all three repos side by side" above. All three must sit next to each
   other, with their original names.

8. You switched branch, and now the web container fails on a package it should have.
   Cause: node_modules lives in a Docker volume that survives `docker compose down`, so a
   branch with different dependencies installs on top of stale packages.
   Fix: clear the volume and rebuild.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml down -v
    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build

   **`-v` does delete your database**, because that is a volume too. Run step 2 afterwards to
   put it back. Your code is not touched, the repos are bind mounted rather than copied.

9. You trigger an email and nothing appears at http://localhost:8025.
   Cause: nearly always an api container started before the mail catcher existed, so it
   still has no `DF_SMTP_ADDRESS` and is writing files instead.
   Fix: recreate it. `restart` does not pick up new environment variables.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d doubtfire-api

   Confirm with `docker exec doubtfire-api printenv DF_SMTP_ADDRESS`, which should print
   `df-compose-mailpit`.

10. The api container will not start. Error: "Could not find <some gem> in locally installed
   gems (Bundler::GemNotFound)".
   Cause: somebody added a gem to the api `Gemfile`. Gems are installed into the image when
   it is built, not into a volume, so a container started from the old image does not have
   it. The api then crash-loops before it ever listens on port 3000.
   Fix: rebuild the image.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build doubtfire-api

   Running `bundle install` with `docker exec` looks like it works and does not survive.
   The gems land in the running container's writable layer and are thrown away the next
   time the container is recreated.

11. The app starts throwing 500s while you are using it, and the log says
   "ActiveRecord::LockWaitTimeout: Lock wait timeout exceeded".
   Cause: **the test suite and the app share one database.** The compose file sets
   `DF_TEST_DB_DATABASE` and `DF_DEV_DB_DATABASE` to the same value, `doubtfire-dev`. Tests
   hold long transactions, so anything you do in the browser at the same time queues behind
   them until it times out. Tests also change and delete your seeded data.
   Fix: do not run `rails test` while anyone is using the app, and never during a demo. Run
   `rake db:populate` afterwards if your data looks wrong.

   This is not something the notification work introduced. It is how the stack has always
   been configured.

12. You post a comment, get a 403 back, and no email arrives. The error says "Comment
   duplicates last comment, so ignored".
   Cause: OnTrack drops a comment whose text is identical to the previous comment on that
   task. No comment is created, so no notification and no email. This is existing behaviour
   in `app/api/task_comments_api.rb`, not something notifications introduced.
   Fix: type something different. When rehearsing a demo, vary the text each time.

13. `git status` in doubtfire-deploy shows an untracked `doubtfire-overseer/` folder.
   Cause: it is a leftover checkout from another branch. `11.0.x` does not use it. Most
   people will never see it.
   Fix: none needed. Leave it alone. Do not `git add` it and do not delete it.

14. `rake db:populate` fails part way through. Error: "Error on rename of
   './doubtfire@002ddev/<some table>' to './doubtfire@002ddev/#sql-backup-1-7' (errno: 194
   "Tablespace is missing for a table")".
   **This is a Windows problem and it is not your data.** It happens on a completely fresh
   database, so deleting things and starting again does not help. Three people tried that and
   got the identical error on the identical table.
   Cause: the database used to live in a bind mount, `../data/database`, a folder on your own
   machine shared into the container. InnoDB cannot reliably rename a table across that share
   on Windows, and it reports errno 194. Loading the schema renames tables while it adds
   foreign keys, so `db:populate` trips over it on the first table in that pass every time.
   It is not a Rails problem and it is not corruption. See docker-library/mariadb#331, which
   reproduces it in three SQL statements.
   Fix: already fixed. The database is a named Docker volume now, which lives inside Docker's
   own filesystem and never touches the Windows one. Pull the latest `11.0.x`, then:

   ```bash
   docker compose -f docker-compose.yml -f docker-compose.local-paths.yml down -v

   docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d

   docker compose -f docker-compose.yml -f docker-compose.local-paths.yml run --rm doubtfire-api bash -c "bundle exec rake db:populate"
   ```

   The old `doubtfire-deploy/data/database` folder is dead after that and you can delete it.
   Nothing reads it any more.
   You will usually see the api container die too, because it migrates on boot. Same problem,
   and the same reset fixes both.

15. `bundle exec rake db:populate` fails instantly. On Windows the error is "WSL ... ERROR:
   CreateProcessCommon:800: execvpe(/bin/bash) failed: No such file or directory". On macOS
   it is "bundle: command not found".
   Cause: the command ran on your own machine instead of inside the api container. Ruby and
   the gems are only in the container. Nothing needs to be installed on your machine.
   Fix: use the whole command from step 2. The part before `bash -c` is not optional.

     ```bash
     docker compose -f docker-compose.yml -f docker-compose.local-paths.yml run --rm doubtfire-api bash -c "bundle exec rake db:populate"
     ```

     This single-line form avoids the PowerShell line-continuation issue.

## Notes

- Docker mounts your local folders. The web and api run your branch code, including changes
  you have not committed yet.
- The first time you move to `11.0.x` you must rebuild the images with `--build`. Old images
  will not work.
- Only ports 3000 and 4200 are reachable from your machine. The database and Redis are
  internal to Docker, so a database client on your Mac cannot connect to them. To look at the
  database, go through the container:

    docker exec -it doubtfire-api bash -c "bundle exec rails console"

- The compose files still carry image tags that say `8.0.x-dev`. If you already have an old
  image cached under that name, Docker reuses it instead of building a new one. That is what
  causes problems 1 and 2. It is why `--build` matters.

## Peer Progress Indicator configuration

The local API container receives these non-secret development defaults:

- `DF_PPI_MINIMUM_COHORT_SIZE=21`
- `DF_PPI_STALE_AFTER_HOURS=48`

`DF_PPI_MINIMUM_COHORT_SIZE=21` matches the API's own floor.
`PeerProgressApi::MINIMUM_SAFE_COHORT_SIZE` is 21 and `minimum_cohort_size!`
returns 503 for anything below it, so a lower value disables the endpoint for
enabled units rather than publishing a smaller cohort. You can raise this
value, you cannot lower it. `positive_integer_env!` separately rejects a
missing, zero, negative or non-integer value.

The floor is 21 because the API quantises percentages into 10-point buckets.
At 20 students each student accounts for exactly half a bucket, leaving some
rounded outputs that map to only one possible submitted count. At 21 students
each student's share is smaller than half a bucket, so every published output
maps to at least two possible counts, including the edge buckets. Changing
either number without the other breaks that guarantee, so
`MINIMUM_SAFE_COHORT_SIZE` and `PERCENTAGE_BUCKET_SIZE` are asserted together
in the API test suite.

Deploy this value together with the API privacy fix that raises
`PeerProgressApi::MINIMUM_SAFE_COHORT_SIZE` to 21. The deploy and API changes
must not be merged independently.

`DF_PPI_STALE_AFTER_HOURS=48` is the local maximum snapshot age. A snapshot
older than this is returned as stale, and the response withholds the
percentage entirely rather than returning an old one.

The local Compose stack starts Redis, but it does not start a Sidekiq worker.
To test PPI locally, first list the active unit IDs:

```bash
docker exec doubtfire-api bundle exec rails runner \
  'Unit.active_units.order(:id).pluck(:id).each { |id| puts id }'
```

If this prints no unit IDs, complete step 2 of **Steps to run** above
(*Set up the database*) using `db:populate`, then run the command again.

Choose a test unit ID and replace `123` in the following commands. Clear any
existing rows and record the count first, or a second run reads as a pass even
when the job raised:

```bash
docker exec doubtfire-api bundle exec rails runner \
  'Unit.find(123).update!(peer_progress_enabled: true)'

docker exec doubtfire-api bundle exec rails runner \
  'PeerProgressSnapshot.where(unit_id: 123).delete_all; \
   puts "BEFORE=#{PeerProgressSnapshot.where(unit_id: 123).count}"'

docker exec doubtfire-api bundle exec rails runner \
  'AggregatePeerProgressJob.new.perform(123)'

docker exec doubtfire-api bundle exec rails runner \
  'puts "AFTER=#{PeerProgressSnapshot.where(unit_id: 123).count}"'
```

`BEFORE=0` followed by an `AFTER` above zero confirms that stored
peer-progress snapshots were created by this run. An `AFTER` of zero means the
selected unit did not have suitable seeded projects, tasks, or target-grade
cohorts.

Seeded units are small, so most target-grade cohorts will sit under the floor
of 21 and the endpoint will read as unavailable even once snapshots exist.
That is correct behaviour, not a broken setup. To see a number, seed a larger
target-grade cohort. Never lower the configured floor; raising it hides more
small cohorts rather than making them visible.

Production deployments must supply separately reviewed values through their
own configuration. These values are not secrets.
