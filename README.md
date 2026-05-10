<div align="center">

# mailcow-vps-relay

[![Version](https://img.shields.io/github/v/release/krahlos/mailcow-vps-relay)](https://github.com/krahlos/mailcow-vps-relay/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

_Mail relay on a public VPS bridging the internet and a [Mailcow](https://mailcow.email)
instance behind CGNAT/DS-Lite over IPv6. Includes automatic TLS via Let's Encrypt and
Prometheus metrics._

</div>

---

See [ARCHITECTURE.md](ARCHITECTURE.md) for design overview, [INSTALL.md](INSTALL.md) for
full setup instructions, and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common connectivity issues.

## Quick start

```bash
git clone https://github.com/krahlos/mailcow-vps-relay.git /opt/mailcow-vps-relay
cd /opt/mailcow-vps-relay
cp .env.example .env
# edit .env — set RELAY_HOSTNAME, RELAY_DOMAINS, MAILCOW_IPV6, ACME_EMAIL,
#              DNS_PROVIDER and the matching *_API_TOKEN

sudo ln -s /opt/mailcow-vps-relay/systemd/mailcow-vps-relay.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mailcow-vps-relay
```

## Management

```bash
sudo systemctl status mailcow-vps-relay
sudo systemctl restart mailcow-vps-relay
docker compose -f /opt/mailcow-vps-relay/docker-compose.yml logs -f
```

## TLS certificates (DNS-01)

Certbot uses a DNS-01 challenge — it never binds host port 80 or 443, so a reverse
proxy (Gerbil/Traefik/Nginx) can permanently own those ports. The DNS provider is selected
at runtime via `DNS_PROVIDER` in `.env`.

### Supported providers

| `DNS_PROVIDER` | Required env var       | Token scope                                     |
| -------------- | ---------------------- | ----------------------------------------------- |
| `cloudflare`   | `CLOUDFLARE_API_TOKEN` | `Zone:DNS:Edit` on the zone with RELAY_HOSTNAME |
| `hetzner`      | `HETZNER_API_TOKEN`    | DNS Console API token                           |
| `infomaniak`   | `INFOMANIAK_API_TOKEN` | `Domain` scope on the relevant product          |

Only the row matching your `DNS_PROVIDER` needs to be set; leave the others empty.
`renew.sh` writes the plugin-specific credentials INI to `/etc/letsencrypt/`
with `0600` permissions on every container start.

### First issuance

```bash
docker compose up -d --build certbot
docker compose logs -f certbot  # watch issuance succeed
docker compose exec certbot ls -lah /etc/letsencrypt/live/$RELAY_HOSTNAME
```

### Verify renewal

No host port is required for renewal either, so you can test it with:

```bash
docker compose exec certbot certbot renew --dry-run
```

## Monitoring

Prometheus metrics at `http://<vps>:9154/metrics` (localhost-only by default).

## Roadmap

- [x] Inbound STARTTLS via Certbot sidecar
- [x] Postfix metrics via `postfix-exporter`
- [ ] Fail2Ban container for port 25 brute-force protection
- [ ] Rspamd pre-filter before forwarding to Mailcow
- [x] Outbound relay path (`relayhost = [relay.example.com]:587`)
- [ ] IMAP proxy (ports 143/993) for mail clients behind CGNAT
- [ ] WireGuard tunnel as alternative VPS↔Mailcow transport (for setups without IPv6)
