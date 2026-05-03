#!/bin/sh
set -e

if [ -z "${RELAY_HOSTNAME}" ]; then
    echo "ERROR: RELAY_HOSTNAME must be set"
    exit 1
fi

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

# Render helo_access from template (texthash: reads plain text directly)
envsubst < /etc/postfix/helo_access.tmpl > /etc/postfix/helo_access

# Create SASL credentials for submission (mailcow outbound relay)
if [ -n "${SUBMISSION_USER}" ] && [ -n "${SUBMISSION_PASS}" ]; then
    printf '%s' "${SUBMISSION_PASS}" | saslpasswd2 -p -c -u "${RELAY_HOSTNAME}" "${SUBMISSION_USER}"
    chown root:postfix /etc/sasl2/sasldb2
    chmod 640 /etc/sasl2/sasldb2
fi

# Start syslog daemon writing to file (for postfix-exporter)
# then tail the file to stdout so docker logs still works
mkdir -p /var/log/postfix
syslogd -O /var/log/postfix/mail.log
tail -F /var/log/postfix/mail.log &

exec /usr/sbin/postfix start-fg
