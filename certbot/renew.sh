#!/bin/sh
set -eu

: "${RELAY_HOSTNAME:?RELAY_HOSTNAME is required}"
: "${ACME_EMAIL:?ACME_EMAIL is required}"
: "${DNS_PROVIDER:?DNS_PROVIDER is required (see /providers/*.sh)}"

PROVIDERS_DIR="/providers"
PROVIDER_FILE="${PROVIDERS_DIR}/${DNS_PROVIDER}.sh"
CERT="/etc/letsencrypt/live/${RELAY_HOSTNAME}/fullchain.pem"

umask 077

if [ ! -f "${PROVIDER_FILE}" ]; then
    available=$(find "${PROVIDERS_DIR}" -maxdepth 1 -name '*.sh' -exec basename {} .sh \; 2>/dev/null | sort | tr '\n' ' ')
    echo "[certbot] unsupported DNS_PROVIDER='${DNS_PROVIDER}'. Available: ${available}" >&2
    exit 1
fi

# Provider script must validate its own credentials, write its INI, and set
# CREDS_FILE + PLUGIN_ARGS. See /providers/cloudflare.sh for the contract.
CREDS_FILE=""
PLUGIN_ARGS=""
# shellcheck disable=SC1090
. "${PROVIDER_FILE}"

if [ -z "${CREDS_FILE}" ] || [ -z "${PLUGIN_ARGS}" ]; then
    echo "[certbot] provider '${DNS_PROVIDER}' did not set CREDS_FILE / PLUGIN_ARGS" >&2
    exit 1
fi
chmod 600 "${CREDS_FILE}"

echo "[certbot] DNS-01 provider: ${DNS_PROVIDER}"

if [ ! -f "${CERT}" ]; then
    echo "[certbot] issuing new certificate for ${RELAY_HOSTNAME}"
    # shellcheck disable=SC2086
    certbot certonly \
        ${PLUGIN_ARGS} \
        --non-interactive \
        --agree-tos \
        --email "${ACME_EMAIL}" \
        -d "${RELAY_HOSTNAME}"
else
    echo "[certbot] existing certificate found at ${CERT}"
fi

trap exit TERM
while :; do
    echo "[certbot] running renewal check"
    # shellcheck disable=SC2086
    certbot renew \
        ${PLUGIN_ARGS} \
        --non-interactive
    sleep 12h & wait $!
done
