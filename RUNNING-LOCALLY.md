# Running OnTrack Locally (web and api)

This file explains how to run OnTrack on your computer with Docker. It covers the web
app and the api. It also lists the problems we hit and how to fix them.

## What runs

- doubtfire-api: the backend (Rails). Port 3000.
- doubtfire-web: the frontend (Angular). Port 4200.
- A database (MariaDB) and Redis. Docker starts these for you.

## Before you start

- Install Docker Desktop and start it.
- Set your git remotes: origin is the team org fork, upstream is thoth-tech.
- Work on branch 11.0.x, or on your feature branch made from 11.0.x.
- Do not use the development branch. It is old and frozen (June 2024).
- You do not install Ruby or Node on your computer. They live inside the Docker images.
  The api needs Ruby 3.4. The web needs Node 22.
- Do not run rails, rubocop, or bundle on your computer. Your Mac has old Ruby (2.6).
  Run those inside the Docker container instead.

## Steps to run

All commands run from the deploy folder:

    cd doubtfire-deploy/development

1. Build and start everything. Use --build the first time and after you switch to 11.0.x.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build

   The first build is slow. It installs gems and node packages.

2. Set up the database. Do this the first time, or any time the database is broken.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml run --rm --no-deps doubtfire-api \
      bash -c "bundle exec rake db:drop db:create db:schema:load && bundle exec rails db:environment:set RAILS_ENV=development && bundle exec rake db:populate"

3. Make sure the app is up.

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d

4. Open the app.

   - Web: http://localhost:4200
   - API docs: http://localhost:3000/api/docs

5. Log in. All test users use the password "password".

   - Student: student_1
   - Admin: aadmin
   - Convenor: aconvenor
   - Tutor: atutor

   Log in as student_1 to see the cross-unit dashboard at /dashboard.

## How to check it is working

- See the containers:

    docker ps

- Check the api answers (from inside the container):

    docker exec doubtfire-api curl -s localhost:3000/api/settings

- Check the web can reach the api through its proxy (you want 200):

    docker exec doubtfire-web curl -s -o /dev/null -w "%{http_code}\n" localhost:4200/api/settings

- Read the logs:

    docker logs doubtfire-api
    docker logs doubtfire-web

## Problems and fixes

1. The api will not start. Error: "Your Ruby version is 3.1.7, but your Gemfile specified ~> 3.4.0".
   Cause: the image was built with old Ruby. 11.0.x needs Ruby 3.4.
   Fix: rebuild the images. Add --build to the up command.

2. The web will not start. Error: "The Angular CLI requires a minimum Node.js version of v22".
   Cause: the image was built with old Node. 11.0.x needs Node 22.
   Fix: rebuild the images. Add --build.

3. up stops at once. Error: "service overseer-worker-1 has neither an image nor a build context".
   Cause: the old local-paths file had overseer services with no image.
   Fix: already fixed. The local-paths file now only has api and web.

4. The web crashes. Error: "Missing script: start-compose".
   Cause: 11.0.x renamed that script to "start".
   Fix: already fixed. The local-paths file runs "npm start".

5. The api crashes while migrating. Error: "Table 'doubtfire-dev.task_prerequisites' doesn't exist".
   Cause: the database has old, half-set-up data.
   Fix: reset the database. Run step 2 above (drop, create, schema:load, populate).

6. The app loads but shows "Temporarily Unavailable" and the title stays "Loading...".
   Cause: the web app cannot reach the api. The proxy points at localhost:3000, which is
   wrong inside the container. The api is a different container named doubtfire-api.
   Fix: already fixed. The local-paths file mounts proxy.conf.docker.json, which points at
   doubtfire-api:3000. If you still see the error, rebuild the web container and reload:

    docker compose -f docker-compose.yml -f docker-compose.local-paths.yml up -d --build doubtfire-web

## Notes

- Docker mounts your local folders. The web and api run your branch code, including
  changes you have not committed yet.
- The first time you move to 11.0.x you must rebuild the images with --build. Old images
  will not work.
