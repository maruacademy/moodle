#!/usr/bin/env bash
set -euo pipefail

PID_FILE="/run/nginx.pid"

echo "[Post-Deploy] Validating Nginx configuration..."
nginx -t

PID=$(tr -d '[:space:]' < "$PID_FILE" 2>/dev/null || true)

if systemctl is-active --quiet nginx && [[ "$PID" =~ ^[0-9]+$ ]] && kill -0 "$PID" 2>/dev/null; then
  echo "[Post-Deploy] Nginx is active (PID $PID). Performing graceful reload..."
  systemctl reload nginx
else
  echo "[Post-Deploy] Nginx PID file empty/stale or service inactive. Recovering via clean restart..."
  rm -f "$PID_FILE"

  # Gracefully drain any orphaned Nginx master process not tracked by systemd
  if pgrep -f "nginx: master process" >/dev/null 2>&1; then
    echo "[Post-Deploy] Sending SIGQUIT to orphaned Nginx master process..."
    pkill -QUIT -f "nginx: master process" || true
    for _ in {1..10}; do
      pgrep -f "nginx: master process" >/dev/null 2>&1 || break
      sleep 0.5
    done
  fi

  systemctl restart nginx
fi

echo "[Post-Deploy] Nginx is running cleanly (PID $(tr -d '[:space:]' < "$PID_FILE"))."
