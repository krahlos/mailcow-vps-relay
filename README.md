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
# edit .env — set RELAY_HOSTNAME, RELAY_DOMAINS, MAILCOW_IPV6, ACME_EMAIL

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

## Monitoring

Prometheus metrics at `http://<vps>:9154/metrics` (localhost-only by default).

## Roadmap

- [x] Inbound STARTTLS via Certbot sidecar
- [x] Postfix metrics via `postfix-exporter`
- [ ] Fail2Ban container for port 25 brute-force protection
- [ ] Rspamd pre-filter before forwarding to Mailcow
- [ ] Outbound relay path (`relayhost = [relay.example.com]:587`)
