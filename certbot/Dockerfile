# Wrapper image bundling certbot with DNS-01 plugins for every provider the
# stack supports. The active provider is chosen at runtime via $DNS_PROVIDER
# in renew.sh; this image just makes every plugin available.
#
# Pinned plugins:
#   certbot-dns-cloudflare  5.5.0  — official, matches certbot base
#   certbot-dns-hetzner     2.0.0  — third-party (github.com/ctrlaltcoop/certbot-dns-hetzner)
#   certbot-dns-infomaniak  0.2.2  — third-party (github.com/Infomaniak/certbot-dns-infomaniak)
#
# Bump these only together with a deliberate audit of the upstream changelogs.

ARG CERTBOT_VERSION=v5.5.0
FROM certbot/certbot:${CERTBOT_VERSION}

RUN pip install --no-cache-dir \
        certbot-dns-cloudflare==5.5.0 \
        certbot-dns-hetzner==2.0.0 \
        certbot-dns-infomaniak==0.2.2
