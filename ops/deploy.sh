#!/usr/bin/env bash
set -euo pipefail

repo=yubin7887/hhhhhhhh
app=/home/ubuntu/app.jar
state=/home/ubuntu/.local/state/hackathon-deploy
health_url=${HEALTH_URL:-http://127.0.0.1:8080/api/hello}

umask 077
mkdir -p "$state"
exec 9>"$state/lock"
flock -n 9 || exit 0

head=$(gh api "repos/$repo/git/ref/heads/main" --jq '.object.sha')
if [[ -f "$state/deployed" && $(<"$state/deployed") == "$head" ]]; then
  exit 0
fi

run=$(gh api --method GET "repos/$repo/actions/workflows/ci.yml/runs" \
  -f branch=main -f event=push -f status=success -f head_sha="$head" \
  --jq '.workflow_runs[0].id // empty')
[[ -n "$run" ]] || exit 0
if [[ -f "$state/failed" && $(<"$state/failed") == "$run" ]]; then
  exit 0
fi

# Stage beside the current JAR so rename is atomic.
stage=$(mktemp -d /home/ubuntu/.hackathon-deploy.XXXXXXXX)
trap 'rm -rf -- "$stage"' EXIT
gh run download "$run" --repo "$repo" --name hackathon-app --dir "$stage"
[[ -s "$stage/app.jar" ]]
[[ $(gh api "repos/$repo/git/ref/heads/main" --jq '.object.sha') == "$head" ]] || exit 0

# Require a known rollback target and preserve the service's existing file mode.
cp -p -- "$app" "$stage/previous.jar"
chmod --reference="$app" "$stage/app.jar"
mv -f -- "$stage/app.jar" "$app"

healthy() {
  for ((attempt=0; attempt<30; attempt++)); do
    if systemctl is-active --quiet hackathon &&
       [[ $(curl --silent --max-time 3 --output /dev/null --write-out '%{http_code}' "$health_url") == 200 ]]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if sudo -n systemctl restart hackathon && healthy; then
  printf '%s\n' "$head" > "$state/deployed.new"
  mv -f -- "$state/deployed.new" "$state/deployed"
  printf 'Deployed %s (Actions run %s) and verified API HTTP 200\n' "$head" "$run"
else
  printf 'Deploy failed for %s (Actions run %s); restoring previous JAR\n' "$head" "$run" >&2
  printf '%s\n' "$run" > "$state/failed"
  mv -f -- "$stage/previous.jar" "$app"
  if sudo -n systemctl restart hackathon && healthy; then
    printf 'Verified previous JAR after rollback\n' >&2
  else
    printf 'Rollback health check failed\n' >&2
  fi
  exit 1
fi
