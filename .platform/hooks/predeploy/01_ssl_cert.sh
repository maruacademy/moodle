#!/bin/bash
set -e

CERT_DIR="/etc/pki/tls/certs"
KEY_DIR="/etc/pki/tls/private"
CERT_FILE="${CERT_DIR}/server.crt"
KEY_FILE="${KEY_DIR}/server.key"

mkdir -p "$CERT_DIR" "$KEY_DIR"

if [ ! -f "$CERT_FILE" ] || [ ! -f "$KEY_FILE" ]; then
    echo "Generating self-signed SSL certificate for backend ALB re-encryption..."
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$KEY_FILE" \
        -out "$CERT_FILE" \
        -subj "/CN=localhost/O=MaruMoodle/C=AU"

    chmod 600 "$KEY_FILE"
    chmod 644 "$CERT_FILE"
fi
