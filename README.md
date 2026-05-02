<div align="center">

# mailcow-vps-relay

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

_Postfix relay running on a public VPS that forwards inbound mail over IPv6 to a
[Mailcow](https://mailcow.email) instance behind CGNAT/DS-Lite. Includes automatic
TLS via Let's Encrypt_

</div>

---

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full design overview.

## Quick start

```bash
cp .env.example .env
# edit .env — set RELAY_HOSTNAME, RELAY_DOMAINS, MAILCOW_IPV6, ACME_EMAIL
docker compose up -d --build
```

Certbot obtains the TLS certificate on first start. Restart postfix once it is ready:

```bash
docker compose restart postfix
```

## Requirements

- VPS with a public IPv4 and IPv6, ports 25 and 80 unblocked
- Mailcow reachable on IPv6 port 25 from the VPS
- VPS IPv6 added to Mailcow's `mynetworks`
- PTR record for the VPS IP matching `RELAY_HOSTNAME`

## Monitoring

Prometheus metrics are exposed at `http://<vps>:9154/metrics` (localhost-only by default).
