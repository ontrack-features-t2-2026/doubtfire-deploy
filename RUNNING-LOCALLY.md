# Running OnTrack locally (web and api)

How to run OnTrack on your computer with Docker. It also lists the problems we hit and how
to fix them.

## What runs

- doubtfire-api: the backend (Rails). Port 3000.
- doubtfire-web: the frontend (Angular). Port 4200.
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

The app does not send real email in development. It writes each one to a file.

Those files land in **doubtfire-deploy/data/tmp/mails/**, because the container mounts
`../data/tmp` over its own `tmp` folder.

The comment in `doubtfire-api/config/environments/development.rb` says they land in
`doubtfire-api/tmp/mails`. That comment is wrong under Docker. Looking there shows you an
empty folder and makes it look like email is broken.

If the mails folder is not there at all, no email has been sent yet.

A mail catcher with a real web inbox is planned (ticket EN-F02) and will replace this.

## How to check it is working

- See the containers:

    docker ps

- Check the api answers, from inside the container:

    docker exec doubtfire-api curl -s localhost:3000/api/settings

- Check the web can reach the api through its proxy. You want 200:

    docker exec doubtfire-web curl -s -o /dev/null -w "%{http_code}\n" localhost:4200/api/settings

- Read the logs:

    docker logs doubtfire-api
    docker logs doubtfire-web

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
   The database lives in a folder on your machine (`doubtfire-deploy/data/database`), so
   `docker compose down -v` does not clear it. Step 2 is the way to reset it.

6. The app loads but shows "Temporarily Unavailable" and the title stays "Loading...".
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

   This does not delete your database. That lives in a bind-mounted folder, not a volume.

9. `git status` in doubtfire-deploy shows an untracked `doubtfire-overseer/` folder.
   Cause: it is a leftover checkout from another branch. `11.0.x` does not use it. Most
   people will never see it.
   Fix: none needed. Leave it alone. Do not `git add` it and do not delete it.

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
