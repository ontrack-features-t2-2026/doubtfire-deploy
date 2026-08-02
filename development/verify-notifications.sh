#!/usr/bin/env bash
# Checks the notification stack end to end without opening a browser.
#
# Run from this folder:  bash verify-notifications.sh
#
# Checks the stack the way DEMO.md walks through it. Read that first.
#
# Every check prints PASS or FAIL and the script exits non-zero if any failed,
# so it is safe to run before a demo or after pulling someone else's branch.
#
# Do NOT run this while `rails test` is running. The test suite and the app share
# one database (DF_TEST_DB_DATABASE and DF_DEV_DB_DATABASE are both
# doubtfire-dev), so the tests hold locks that make step 8 time out with a 500
# that has nothing to do with the notification code.

fails=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; fails=$((fails + 1)); }
check() { # check <description> <expected> <actual>
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (wanted '$2', got '$3')"; fi
}

http() { curl -s -o /dev/null -w '%{http_code}' "$1"; }

echo
echo "1. Containers"
for c in doubtfire-api doubtfire-web df-compose-dev-db df-compose-mailpit; do
  state=$(docker inspect -f '{{.State.Running}}' "$c" 2>/dev/null || echo missing)
  check "$c is running" "true" "$state"
done

echo
echo "2. Ports answer"
check "api    :3000/api/settings" "200" "$(http http://localhost:3000/api/settings)"
check "web    :4200"              "200" "$(http http://localhost:4200/)"
check "mailpit:8025"              "200" "$(http http://localhost:8025/)"

echo
echo "3. Web can reach the api through its proxy"
check "web -> api" "200" "$(docker exec doubtfire-web curl -s -o /dev/null -w '%{http_code}' localhost:4200/api/settings 2>/dev/null)"

echo
echo "4. Mail goes to the catcher, not to a file  (EN-F02)"
check "delivery_method" "smtp" "$(docker exec doubtfire-api printenv DF_SMTP_ADDRESS >/dev/null 2>&1 && echo smtp || echo file)"
check "smtp host"       "df-compose-mailpit" "$(docker exec doubtfire-api printenv DF_SMTP_ADDRESS 2>/dev/null | tr -d '\r')"

echo
echo "5. Push subscription api is mounted  (MN-F01)"
paths=$(curl -s http://localhost:3000/api/swagger_doc | python3 -c "import sys,json;print('yes' if '/api/push_subscriptions' in json.load(sys.stdin).get('paths',{}) else 'no')" 2>/dev/null)
check "/api/push_subscriptions in the api docs" "yes" "$paths"
table=$(docker exec doubtfire-api bash -c "bundle exec rails runner 'puts \"R::\" + PushSubscription.table_exists?.to_s' 2>/dev/null" | grep -o 'R::.*' | cut -d: -f3)
check "push_subscriptions table exists" "true" "$table"

echo
echo "6. Push keys are loaded  (MN-F02)"
cfg=$(docker exec doubtfire-api bash -c "bundle exec rails runner 'puts \"R::\" + PushNotificationService.configured?.to_s' 2>/dev/null" | grep -o 'R::.*' | cut -d: -f3)
check "PushNotificationService.configured?" "true" "$cfg"

echo
echo "7. Service worker is served  (MN-F03)"
check "GET /ngsw-worker.js" "200" "$(http http://localhost:4200/ngsw-worker.js)"
check "GET /ngsw.json"      "200" "$(http http://localhost:4200/ngsw.json)"

echo
echo "8. A comment really does send an email"
before=$(curl -s http://localhost:8025/api/v1/messages | python3 -c "import sys,json;print(json.load(sys.stdin)['messages_count'])" 2>/dev/null)
token=$(docker exec doubtfire-api bash -c "bundle exec rails runner \"u=User.find_by(username:'acain'); puts 'R::'+u.generate_authentication_token!.authentication_token\" 2>/dev/null" | grep -o 'R::.*' | cut -d: -f3)
# The text must be different every run. OnTrack drops a comment that duplicates
# the previous one on the same task and answers 403 "Comment duplicates last
# comment, so ignored" (task_comments_api.rb). A fixed string here makes the
# script pass, then fail, then pass, depending on what ran last. No notification
# is raised for a dropped duplicate, which is correct but worth knowing when a
# demo comment produces no email.
body="verify-notifications.sh check $(date +%s) $$"
code=$(curl -s -o /tmp/verify-comment-body -w '%{http_code}' \
  -X POST "http://localhost:3000/api/projects/2/task_def_id/1/comments/" \
  -H "Username: acain" -H "Auth-Token: $token" -H "Content-Type: application/json" \
  -d "{\"comment\":\"$body\"}")
check "POST a task comment" "201" "$code"
[ "$code" = "201" ] || echo "        response: $(head -c 200 /tmp/verify-comment-body)"
sleep 3
after=$(curl -s http://localhost:8025/api/v1/messages | python3 -c "import sys,json;print(json.load(sys.stdin)['messages_count'])" 2>/dev/null)
if [ "$after" -gt "$before" ]; then
  pass "mailpit received the email ($before -> $after)"
else
  fail "mailpit did not receive an email ($before -> $after)"
fi

echo
echo "9. Nothing is being swallowed"
# Email and push failures are logged and swallowed on purpose, so the log is the
# only place they show up. Scoped to the last five minutes: this is a pre-demo
# check, and an error from earlier in the day says nothing about right now. The
# comment posted in step 8 is well inside that window.
errs=$(docker logs --since 5m doubtfire-api 2>&1 | grep -c "Failed to send notification email\|Failed to push to subscription")
check "swallowed notification errors in the last 5 minutes" "0" "$errs"

echo
if [ "$fails" -eq 0 ]; then
  printf '\033[32mAll checks passed.\033[0m  Read the mail at http://localhost:8025\n\n'
else
  printf '\033[31m%s check(s) failed.\033[0m  See doubtfire-deploy/RUNNING-LOCALLY.md\n\n' "$fails"
fi
exit "$fails"
