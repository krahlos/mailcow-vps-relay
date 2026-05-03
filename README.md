<div align="center">

# mailcow-vps-relay

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

_Mail relay on a public VPS bridging the internet and a
[Mailcow](https://mailcow.email) instance behind CGNAT/DS-Lite over IPv6. Includes
automatic TLS via Let's Encrypt and Prometheus metrics._

</div>

---

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full design overview.

## Quick start

```bash
cp .env.example .env
# edit .env — set RELAY_HOSTNAME, RELAY_DOMAINS, MAILCOW_IPV6, ACME_EMAIL
docker compose up -d --build
```

## Requirements

- VPS with a public IPv4 and IPv6, ports 25 and 80 unblocked
- Mailcow reachable on IPv6 port 25 from the VPS
- VPS IPv6 added to Mailcow's `mynetworks`
- PTR record for the VPS IP matching `RELAY_HOSTNAME`

## Monitoring

Prometheus metrics are exposed at `http://<vps>:9154/metrics` (localhost-only by default).

## Future improvements

- [x] **Inbound TLS (STARTTLS):** Certbot sidecar container, certificate mounted as a
  shared volume, `smtpd_tls_*` directives activated in `main.cf`.
- [x] **Monitoring:** Postfix metrics via `postfix-exporter` for Prometheus scraping.
- [ ] **Fail2Ban:** Brute-force protection on port 25 via a dedicated container.
- [ ] **Rspamd pre-filter:** Spam filtering on the VPS before forwarding to Mailcow,
  reducing load on the Mailcow instance.
- [ ] **Outbound relay path:** Configure Mailcow to route outbound mail through the VPS
  via `relayhost = [mail.example.com]:587`, removing the need for Mailcow to maintain
  its own IPv4 sending reputation.
