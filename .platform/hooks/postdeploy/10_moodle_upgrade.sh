#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/var/app/current"
LOCAL_CACHE_DIR="/tmp/moodle-localcache"
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

warm_caches() {
  echo "Pre-warming Moodle theme CSS, MUC caches, and PHP-FPM OPcache..."

  # 1. Pre-compile active theme SCSS/CSS into $CFG->localcachedir as webapp
  if [ -f "${APP_DIR}/admin/cli/build_theme_css.php" ]; then
    ACTIVE_THEME=$(run_as_webapp php "${APP_DIR}/admin/cli/cfg.php" --name=theme 2>/dev/null | tr -d '[:space:]' || true)
    if [ -n "$ACTIVE_THEME" ]; then
      echo "Building theme CSS for active theme: ${ACTIVE_THEME}..."
      run_as_webapp php "${APP_DIR}/admin/cli/build_theme_css.php" --themes="$ACTIVE_THEME" || true
    else
      echo "Building theme CSS for installed themes..."
      run_as_webapp php "${APP_DIR}/admin/cli/build_theme_css.php" || true
    fi
  fi

  # 2. Warm PHP-FPM OPcache, MUC caches, and revisioned CSS/RequireJS bundles via local HTTPS
  WWW_BASE="${MOODLE_WWWROOT%/}"
  WWW_HOST=$(printf '%s' "$WWW_BASE" | sed -E 's|^https?://||; s|/.*$||')
  CURL_HOST_ARGS=()
  if [ -n "$WWW_HOST" ]; then
    CURL_HOST_ARGS=(-H "Host: ${WWW_HOST}" -H "X-Forwarded-Proto: https")
  fi

  LOGIN_HTML=$(curl -k -s -L --max-time 60 "${CURL_HOST_ARGS[@]}" "https://127.0.0.1/login/index.php" || true)

  if [ -n "$LOGIN_HTML" ] && [ -n "$WWW_BASE" ]; then
    ESCAPED_WWW_BASE=$(printf '%s' "$WWW_BASE" | sed 's/[.[\*^$()+?{|]/\\&/g')
    ASSET_PATHS=$(
      printf '%s' "$LOGIN_HTML" \
        | grep -oE "${ESCAPED_WWW_BASE}/(theme/styles\.php|lib/requirejs\.php|lib/javascript\.php)[^\"'<> ]+" \
        | sed -e 's/&amp;/\&/g' -e "s|^${WWW_BASE}||" \
        | sort -u || true
    )
    for ASSET_PATH in $ASSET_PATHS; do
      curl -k -s -o /dev/null --max-time 60 "${CURL_HOST_ARGS[@]}" "https://127.0.0.1${ASSET_PATH}" || true
    done
  fi

  echo "Cache pre-warming completed."
}

cleanup() {
  if [ "$MAINTENANCE_ACTIVE" -eq 1 ]; then
    echo "Disabling Moodle maintenance mode..."
    run_as_webapp php "${APP_DIR}/admin/cli/maintenance.php" --disable || true
    MAINTENANCE_ACTIVE=0
  fi
}
trap cleanup EXIT

cd "$APP_DIR"

# Moodle's upgrade.php --is-pending exits 2 when an upgrade is pending and 0 when up to date
set +e
PENDING_OUTPUT=$(run_as_webapp php admin/cli/upgrade.php --is-pending 2>&1)
PENDING_RC=$?
set -e

if [ "$PENDING_RC" -eq 2 ] || [[ "$PENDING_OUTPUT" == *"An upgrade is pending"* ]]; then
  echo "Pending Moodle upgrade detected. Enabling maintenance mode..."
  run_as_webapp php admin/cli/maintenance.php --enable
  MAINTENANCE_ACTIVE=1

  echo "Running Moodle CLI database and plugin upgrade..."
  run_as_webapp php admin/cli/upgrade.php --non-interactive

  echo "Purging Moodle caches..."
  run_as_webapp php admin/cli/purge_caches.php

  echo "Disabling Moodle maintenance mode..."
  run_as_webapp php admin/cli/maintenance.php --disable
  MAINTENANCE_ACTIVE=0

  warm_caches

  echo "Moodle CLI upgrade completed successfully."
elif [ "$PENDING_RC" -eq 0 ] || [[ "$PENDING_OUTPUT" == *"No upgrade needed"* ]]; then
  echo "No pending Moodle upgrade detected. Skipping database upgrade."
  if [ -z "$(ls -A "$LOCAL_CACHE_DIR" 2>/dev/null)" ]; then
    echo "Local cache directory (${LOCAL_CACHE_DIR}) is empty. Warming instance caches..."
    warm_caches
  fi
else
  echo "Error checking pending Moodle upgrades (exit code $PENDING_RC):" >&2
  echo "$PENDING_OUTPUT" >&2
  exit 1
fi
