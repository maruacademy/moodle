#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/app/current"
MAINTENANCE_ACTIVE=0

# Load Elastic Beanstalk environment properties for PHP CLI
if [ -f /opt/elasticbeanstalk/deployment/env ]; then
  set -a
  # shellcheck disable=SC1091
  source /opt/elasticbeanstalk/deployment/env
  set +a
fi

cleanup() {
  if [ "$MAINTENANCE_ACTIVE" -eq 1 ]; then
    echo "Disabling Moodle maintenance mode..."
    sudo -E -u webapp php "${APP_DIR}/admin/cli/maintenance.php" --disable || true
  fi
}
trap cleanup EXIT

cd "$APP_DIR"

# --is-pending exits 0 when an upgrade is needed and 1 when already up to date
if sudo -E -u webapp php admin/cli/upgrade.php --is-pending >/dev/null 2>&1; then
  echo "Pending Moodle upgrade detected. Enabling maintenance mode..."
  sudo -E -u webapp php admin/cli/maintenance.php --enable
  MAINTENANCE_ACTIVE=1

  echo "Running Moodle CLI database and plugin upgrade..."
  sudo -E -u webapp php admin/cli/upgrade.php --non-interactive

  echo "Purging Moodle caches..."
  sudo -E -u webapp php admin/cli/purge_caches.php

  echo "Moodle CLI upgrade completed successfully."
else
  echo "No pending Moodle upgrade detected. Skipping."
fi
