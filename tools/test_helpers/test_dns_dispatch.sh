#!/usr/bin/env bash
# Validate the DNS-01 provider dispatcher used by certbot/renew.sh:
#   1. Each provider script in certbot/providers/ exits non-zero when its
#      credential env var is missing.
#   2. Each provider script writes its INI under /etc/letsencrypt/ and sets
#      CREDS_FILE + PLUGIN_ARGS that match the documented contract.
#   3. renew.sh emits a clear "Available: <list>" error for an unknown
#      DNS_PROVIDER.
#
# Runs without docker, certbot, or any network access. Safe in CI.

set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
PROVIDERS_DIR="$REPO_ROOT/certbot/providers"
RENEW_SH="$REPO_ROOT/certbot/renew.sh"

PASS=0
FAIL=0
log_pass() { printf '  PASS %s\n' "$1"; PASS=$((PASS + 1)); }
log_fail() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Sandbox copy of the provider scripts that writes INI to a temp dir
# instead of /etc/letsencrypt/. Mirrors the runtime mount layout.
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/providers" "$SANDBOX/etc/letsencrypt"
for f in "$PROVIDERS_DIR"/*.sh; do
    sed "s|/etc/letsencrypt/|$SANDBOX/etc/letsencrypt/|g" "$f" \
        > "$SANDBOX/providers/$(basename "$f")"
done

stat_mode() {
    stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

assert_fails() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        log_fail "$label (expected failure but command succeeded)"
    else
        log_pass "$label"
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    case "$haystack" in
        *"$needle"*) log_pass "$label" ;;
        *)
            log_fail "$label (missing substring: $needle)"
            printf '    --- output ---\n%s\n    --- end ---\n' "$haystack"
            ;;
    esac
}

check_provider_ok() {
    local provider="$1" token_var="$2" token_val="$3" \
          expected_ini="$4" expected_key="$5" expected_args_substr="$6"

    out=$(
        env -i PATH="$PATH" "$token_var=$token_val" bash -c "
            set -eu
            CREDS_FILE=''
            PLUGIN_ARGS=''
            . '$SANDBOX/providers/${provider}.sh'
            chmod 600 \"\$CREDS_FILE\"
            printf 'CREDS_FILE=%s\n' \"\$CREDS_FILE\"
            printf 'PLUGIN_ARGS=%s\n' \"\$PLUGIN_ARGS\"
        "
    )
    creds=$(printf '%s\n' "$out" | sed -n 's/^CREDS_FILE=//p')
    args=$(printf '%s\n' "$out" | sed -n 's/^PLUGIN_ARGS=//p')

    if [ "$creds" = "$expected_ini" ]; then
        log_pass "$provider CREDS_FILE = $expected_ini"
    else
        log_fail "$provider CREDS_FILE: got '$creds', want '$expected_ini'"
    fi

    case "$args" in
        *"$expected_args_substr"*)
            log_pass "$provider PLUGIN_ARGS contains '$expected_args_substr'"
            ;;
        *)
            log_fail "$provider PLUGIN_ARGS missing '$expected_args_substr' (got: $args)"
            ;;
    esac

    if [ -f "$creds" ]; then
        mode=$(stat_mode "$creds")
        if [ "$mode" = "600" ]; then
            log_pass "$provider INI is mode 600"
        else
            log_fail "$provider INI mode = $mode (want 600)"
        fi
        if grep -q "^${expected_key} = ${token_val}\$" "$creds"; then
            log_pass "$provider INI contains '${expected_key} = <token>'"
        else
            log_fail "$provider INI missing '${expected_key} = ${token_val}': $(cat "$creds")"
        fi
        rm -f "$creds"
    else
        log_fail "$provider INI not created at $creds"
    fi
}

echo "==> provider scripts fail without their token env"
assert_fails "cloudflare without CLOUDFLARE_API_TOKEN" \
    env -i PATH="$PATH" bash -c "set -eu; . '$SANDBOX/providers/cloudflare.sh'"
assert_fails "hetzner without HETZNER_API_TOKEN" \
    env -i PATH="$PATH" bash -c "set -eu; . '$SANDBOX/providers/hetzner.sh'"
assert_fails "infomaniak without INFOMANIAK_API_TOKEN" \
    env -i PATH="$PATH" bash -c "set -eu; . '$SANDBOX/providers/infomaniak.sh'"

echo
echo "==> provider scripts produce CREDS_FILE + PLUGIN_ARGS when token set"
check_provider_ok cloudflare CLOUDFLARE_API_TOKEN tok-cf-XYZ \
    "$SANDBOX/etc/letsencrypt/cloudflare.ini" \
    "dns_cloudflare_api_token" \
    "--dns-cloudflare-credentials"

check_provider_ok hetzner HETZNER_API_TOKEN tok-hz-XYZ \
    "$SANDBOX/etc/letsencrypt/hetzner.ini" \
    "dns_hetzner_api_token" \
    "--dns-hetzner-credentials"

check_provider_ok infomaniak INFOMANIAK_API_TOKEN tok-im-XYZ \
    "$SANDBOX/etc/letsencrypt/infomaniak.ini" \
    "dns_infomaniak_token" \
    "--dns-infomaniak-credentials"

echo
echo "==> renew.sh dispatcher rejects unknown provider with available list"
# Patch renew.sh to use the sandbox paths and to stop before the certbot
# loop (drop everything from `trap exit TERM` onward).
sed \
    -e "s|/providers|$SANDBOX/providers|g" \
    -e "s|/etc/letsencrypt|$SANDBOX/etc/letsencrypt|g" \
    -e '/^trap exit TERM/,$d' \
    "$RENEW_SH" > "$SANDBOX/renew.sh"

err=$(
    DNS_PROVIDER=bogus \
    RELAY_HOSTNAME=relay.example.com \
    ACME_EMAIL=admin@example.com \
    bash "$SANDBOX/renew.sh" 2>&1 || true
)
assert_contains "unknown provider error lists available providers" \
    "Available: cloudflare hetzner infomaniak" "$err"

echo
printf 'TOTAL: %d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
