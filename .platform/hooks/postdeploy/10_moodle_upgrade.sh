#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/app/current"
MAINTENANCE_ACTIVE=0

# Load Elastic Beanstalk environment properties persistently
if [ -x /opt/elasticbeanstalk/bin/get-config ]; then
  eval "$(
    /opt/elasticbeanstalk/bin/get-config environment | python3 -c '
import json, re, shlex, sys
for k, v in json.load(sys.stdin).items():
    if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", k):
        print(f"export {k}={shlex.quote(str(v))}")
'
  )"
elif [ -f /opt/elasticbeanstalk/deployment/env ]; then
  set -a
  # shellcheck disable=SC1091
  source /opt/elasticbeanstalk/deployment/env
  set +a
fi

# Pass MOODLE_* variables explicitly so sudo never strips them
run_as_webapp() {
  sudo -u webapp env \
    MOODLE_DB_HOST="${MOODLE_DB_HOST:-}" \
    MOODLE_DB_NAME="${MOODLE_DB_NAME:-}" \
    MOODLE_DB_USER="${MOODLE_DB_USER:-}" \
    MOODLE_DB_PASS="${MOODLE_DB_PASS:-}" \
    MOODLE_WWWROOT="${MOODLE_WWWROOT:-}" \
    MOODLE_REDIS_HOST="${MOODLE_REDIS_HOST:-}" \
    MOODLE_REDIS_AUTH="${MOODLE_REDIS_AUTH:-}" \
    "$@"
}

cleanup() {
  if [ "$MAINTENANCE_ACTIVE" -eq 1 ]; then
    echo "Disabling Moodle maintenance mode..."
    run_as_webapp php "${APP_DIR}/admin/cli/maintenance.php" --disable || true
  fi
}
trap cleanup EXIT

cd "$APP_DIR"

# --is-pending exits 0 when an upgrade is needed and 1 when already up to date
set +e
PENDING_OUTPUT=$(run_as_webapp php admin/cli/upgrade.php --is-pending 2>&1)
PENDING_RC=$?
set -e

if [ "$PENDING_RC" -eq 0 ]; then
  echo "Pending Moodle upgrade detected. Enabling maintenance mode..."
  run_as_webapp php admin/cli/maintenance.php --enable
  MAINTENANCE_ACTIVE=1

  echo "Running Moodle CLI database and plugin upgrade..."
  run_as_webapp php admin/cli/upgrade.php --non-interactive

  echo "Purging Moodle caches..."
  run_as_webapp php admin/cli/purge_caches.php

  echo "Moodle CLI upgrade completed successfully."
elif [[ "$PENDING_OUTPUT" == *"No upgrade needed"* ]]; then
  echo "No pending Moodle upgrade detected. Skipping."
else
  echo "Error checking pending Moodle upgrades (exit code $PENDING_RC):" >&2
  echo "$PENDING_OUTPUT" >&2
  exit 1
fi

