#!/bin/sh
set -e

# Render main.cf from template
envsubst < /etc/postfix/main.cf.tmpl > /etc/postfix/main.cf

# Enable inbound TLS if certificate is present
CERT="/etc/letsencrypt/live/${RELAY_HOSTNAME}/fullchain.pem"
if [ -f "$CERT" ]; then
    sed -i 's/^##TLS## //' /etc/postfix/main.cf
fi

# Render transport map from template and build hash
envsubst < /etc/postfix/transport.tmpl > /etc/postfix/transport
postmap /etc/postfix/transport

# Build helo_access hash map
postmap /etc/postfix/helo_access

exec /usr/sbin/postfix start-fg
