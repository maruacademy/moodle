#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/app/current"
MAINTENANCE_ACTIVE=0

cleanup() {
  if [ "$MAINTENANCE_ACTIVE" -eq 1 ]; then
    echo "Disabling Moodle maintenance mode..."
    sudo -u webapp php "${APP_DIR}/admin/cli/maintenance.php" --disable || true
  fi
}
trap cleanup EXIT

cd "$APP_DIR"

# --is-pending exits 0 when an upgrade is needed and 1 when already up to date
if sudo -u webapp php admin/cli/upgrade.php --is-pending >/dev/null 2>&1; then
  echo "Pending Moodle upgrade detected. Enabling maintenance mode..."
  sudo -u webapp php admin/cli/maintenance.php --enable
  MAINTENANCE_ACTIVE=1

  echo "Running Moodle CLI database and plugin upgrade..."
  sudo -u webapp php admin/cli/upgrade.php --non-interactive

  echo "Purging Moodle caches..."
  sudo -u webapp php admin/cli/purge_caches.php

  echo "Moodle CLI upgrade completed successfully."
else
  echo "No pending Moodle upgrade detected. Skipping."
fi
