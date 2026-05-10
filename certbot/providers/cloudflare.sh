# shellcheck shell=sh
# shellcheck disable=SC2034  # CREDS_FILE/PLUGIN_ARGS are consumed by renew.sh after sourcing

# Provider plugin: Cloudflare (built-in certbot-dns-cloudflare).
# Required env: CLOUDFLARE_API_TOKEN (Zone:DNS:Edit on the zone with RELAY_HOSTNAME).
# Sourced by renew.sh under `set -eu`; must set CREDS_FILE and PLUGIN_ARGS.

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required for DNS_PROVIDER=cloudflare}"

CREDS_FILE="/etc/letsencrypt/cloudflare.ini"
printf 'dns_cloudflare_api_token = %s\n' "${CLOUDFLARE_API_TOKEN}" > "${CREDS_FILE}"
PLUGIN_ARGS="--dns-cloudflare --dns-cloudflare-credentials ${CREDS_FILE}"
