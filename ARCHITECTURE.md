# Architecture

## Overview

```text
Internet → VPS (IPv4+IPv6, port 25) → Mailcow (IPv6, port 25, home network)
```

Inbound mail arrives at a public VPS and is forwarded over IPv6 to a Mailcow instance behind
CGNAT/DS-Lite. Outbound mail leaves Mailcow directly via IPv6.

## Components

| Component | Role |
| --------- | ---- |
| `postfix` | Accepts inbound SMTP, relays to Mailcow via IPv6 |
| `certbot` | Obtains and renews Let's Encrypt TLS cert via Cloudflare DNS-01 |
| `postfix-exporter` | Exposes Postfix metrics on port 9154 |
| `transport.tmpl` | Maps relay domains to `smtp:[MAILCOW_IPV6]:PORT` |
| `helo_access` | Rejects forged HELO using own hostname |
| `header_checks` | Strips RFC-1918 addresses from `Received:` headers |

## Data flow

1. Remote MTA connects to VPS port 25
2. Postfix checks `relay_domains` and `smtpd_recipient_restrictions`
3. Transport map routes mail to `[MAILCOW_IPV6]:25`
4. Mailcow trusts the VPS IPv6 via `mynetworks` — no auth required

## TLS

Certbot runs as a sidecar using the Cloudflare DNS-01 challenge (`--dns-cloudflare`). It
binds no host ports, so a reverse proxy (Gerbil/Traefik) can permanently own host 80/443.
Certificate stored in shared `letsencrypt` volume. On startup, `entrypoint.sh` activates
`smtpd_tls_*` directives if the cert exists. Renewal runs every 12 hours; contacts Let's
Encrypt only when within 30 days of expiry.

After renewal:

```bash
docker compose restart postfix
```

## Monitoring

`postfix-exporter` (Hsn723 fork) shares two volumes with the postfix container:

| Volume          | Used for                                                |
| --------------- | ------------------------------------------------------- |
| `postfix-logs`  | Log-based metrics (delivered, rejected, deferred rates) |
| `postfix-queue` | Queue depth via showq socket                            |

Metrics at `http://<vps>:9154/metrics`. Port bound to `127.0.0.1` by default.

## Key design decisions

- **No local delivery** — `mydestination` empty; unknown recipients rejected at SMTP time
- **No open relay** — `mynetworks` localhost-only; only listed `relay_domains` accepted
- **Alpine base** — chroot disabled in `master.cf` (jail not pre-populated on Alpine)
- **Config via env vars** — `main.cf` and `transport` rendered at startup by `entrypoint.sh` via `envsubst`
- **TLS opt-in** — STARTTLS activates once cert is present; stack starts without TLS on first boot

## DNS requirements

| Record | Value |
| ------ | ----- |
| MX | `relay.example.com` |
| A/AAAA | VPS IPv4/IPv6 |
| PTR | Must match `RELAY_HOSTNAME` |
| SPF | Include VPS IPv4, VPS IPv6, Mailcow home IPv6 |
