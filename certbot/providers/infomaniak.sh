# shellcheck shell=sh
# shellcheck disable=SC2034  # CREDS_FILE/PLUGIN_ARGS are consumed by renew.sh after sourcing

# Provider plugin: Infomaniak (third-party certbot-dns-infomaniak).
# Required env: INFOMANIAK_API_TOKEN (Domain scope on the relevant product).
# Sourced by renew.sh under `set -eu`; must set CREDS_FILE and PLUGIN_ARGS.

: "${INFOMANIAK_API_TOKEN:?INFOMANIAK_API_TOKEN is required for DNS_PROVIDER=infomaniak}"

CREDS_FILE="/etc/letsencrypt/infomaniak.ini"
printf 'dns_infomaniak_token = %s\n' "${INFOMANIAK_API_TOKEN}" > "${CREDS_FILE}"
PLUGIN_ARGS="--authenticator dns-infomaniak --dns-infomaniak-credentials ${CREDS_FILE}"
