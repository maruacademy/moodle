#!/bin/bash
set -e

echo "[Post-Deploy] Validating Nginx configuration..."
nginx -t

echo "[Post-Deploy] Reloading Nginx service..."
systemctl reload nginx || systemctl restart nginx

echo "[Post-Deploy] Nginx successfully reloaded."
