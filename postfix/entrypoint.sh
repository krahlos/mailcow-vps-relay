#!/bin/sh
set -e

# Render main.cf from template
envsubst < /etc/postfix/main.cf.tmpl > /etc/postfix/main.cf

# Enable inbound TLS if certificate is present
CERT="/etc/letsencrypt/live/${RELAY_HOSTNAME}/fullchain.pem"
if [ -f "$CERT" ]; then
    sed -i 's/^##TLS## //' /etc/postfix/main.cf
fi

# Render transport map from template and build lmdb
envsubst < /etc/postfix/transport.tmpl > /etc/postfix/transport
postmap /etc/postfix/transport

# Start syslog daemon writing to file (for postfix-exporter)
# then tail the file to stdout so docker logs still works
mkdir -p /var/log/postfix
syslogd -O /var/log/postfix/mail.log
tail -F /var/log/postfix/mail.log &

exec /usr/sbin/postfix start-fg
