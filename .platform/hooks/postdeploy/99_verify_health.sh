#!/bin/bash
set -euo pipefail

LOG_TAG="MoodleHealthCheck"

log_info()  { echo "[INFO] [$LOG_TAG] $1"; }
log_error() { echo "[ERROR] [$LOG_TAG] $1" >&2; }

# ==============================================================================
# GET ENDPOINTS
# ==============================================================================

DB_HOST="${DB_HOST:-maru-moodle-db.cluster-crkc8w28olh1.ap-southeast-2.rds.amazonaws.com}"
REDIS_HOST="${REDIS_HOST:-master.marumoodle-redis-tls.trutt8.apse2.cache.amazonaws.com}"

# ==============================================================================
# 2. BACKEND CONNECTIVITY CHECKS
# ==============================================================================
log_info "Verifying backend port connectivity..."

# Test Redis (Port 6379 - Implicit TLS)
if [ -n "$REDIS_HOST" ]; then
    if echo | timeout 3 openssl s_client -connect "${REDIS_HOST}:6379" -servername "${REDIS_HOST}" -brief >/dev/null 2>&1; then
        log_info "Redis TLS connection (6379): SUCCESS ($REDIS_HOST)"
    else
        log_error "Redis TLS connection (6379): FAILED to reach $REDIS_HOST"
        exit 1
    fi
fi

# Test Aurora MySQL (Port 3306 - Explicit STARTTLS)
if [ -n "$DB_HOST" ]; then
    if echo | timeout 3 openssl s_client -starttls mysql -connect "${DB_HOST}:3306" -brief >/dev/null 2>&1; then
        log_info "Aurora DB TLS connection (3306): SUCCESS ($DB_HOST)"
    else
        log_error "Aurora DB TLS connection (3306): FAILED to reach $DB_HOST"
        exit 1
    fi
else
    log_error "Aurora DB TLS connection: DB_HOST endpoint could not be resolved."
    exit 1
fi

# Test EFS Mount Path
if mountpoint -q /mnt/moodledata; then
    log_info "EFS filesystem (/mnt/moodledata): MOUNTED"
else
    log_error "EFS filesystem (/mnt/moodledata): NOT MOUNTED"
    exit 1
fi

# ==============================================================================
# 3. NGINX & PHP-FPM SERVICE VERIFICATION
# ==============================================================================
log_info "Verifying web server and application runtime..."

# Verify systemd service states
for SERVICE in nginx php-fpm; do
    if systemctl is-active --quiet "$SERVICE"; then
        log_info "Service '$SERVICE' is active and running."
    else
        log_error "Service '$SERVICE' is NOT running. Attempting restart..."
        systemctl restart "$SERVICE" || { log_error "Failed to start '$SERVICE'"; exit 1; }
    fi
done

# Validate Nginx configuration syntax
log_info "Validating Nginx syntax..."
nginx -t || { log_error "Nginx configuration syntax failure!"; exit 1; }

# Reload Nginx to ensure active certificates and rules are applied
systemctl reload nginx

# Test Local HTTPS Endpoint (Port 443)
log_info "Testing local HTTPS listener (https://127.0.0.1/)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" https://127.0.0.1/ || echo "000")

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 500 ]; then
    log_info "Local HTTPS endpoint responding cleanly (HTTP $HTTP_CODE)."
else
    log_error "Local HTTPS health check failed (HTTP $HTTP_CODE)."
    exit 1
fi

log_info "Post-deploy health verification completed successfully!"
