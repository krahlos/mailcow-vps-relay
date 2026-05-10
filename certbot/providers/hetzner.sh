# shellcheck shell=sh
# shellcheck disable=SC2034  # CREDS_FILE/PLUGIN_ARGS are consumed by renew.sh after sourcing

# Provider plugin: Hetzner DNS Console (third-party certbot-dns-hetzner).
# Required env: HETZNER_API_TOKEN (DNS Console API token).
# Sourced by renew.sh under `set -eu`; must set CREDS_FILE and PLUGIN_ARGS.

: "${HETZNER_API_TOKEN:?HETZNER_API_TOKEN is required for DNS_PROVIDER=hetzner}"

CREDS_FILE="/etc/letsencrypt/hetzner.ini"
printf 'dns_hetzner_api_token = %s\n' "${HETZNER_API_TOKEN}" > "${CREDS_FILE}"
PLUGIN_ARGS="--authenticator dns-hetzner --dns-hetzner-credentials ${CREDS_FILE}"
