#!/bin/sh
set -e

CERT="/etc/letsencrypt/live/${RELAY_HOSTNAME}/fullchain.pem"

if [ ! -f "$CERT" ]; then
    certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "${ACME_EMAIL}" \
        -d "${RELAY_HOSTNAME}"
fi

trap exit TERM
while :; do
    certbot renew --standalone
    sleep 12h & wait $!
done
