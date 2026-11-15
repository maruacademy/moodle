#!/usr/bin/env bash
# Instead of installing a File Integrity Monitoring (FIM) agent to watch for modified PHP files, enforce immutable permissions
set -e

# Target the staging directory before Beanstalk swaps it to /var/app/current
APP_DIR="/var/app/staging"

echo "Setting immutable application permissions on $APP_DIR..."

# 1. Set root ownership across all Moodle core files
chown -R root:root "$APP_DIR"

# 2. Set strict directory (755) and file (644) permissions
find "$APP_DIR" -type d -exec chmod 755 {} +
find "$APP_DIR" -type f -exec chmod 644 {} +

# 3. Explicitly ensure webapp/nginx CANNOT write to app root
# (Moodle moodledata must already point to /mnt/efs/moodledata)

echo "Permissions hardened successfully."
