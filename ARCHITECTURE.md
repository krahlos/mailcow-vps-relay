# Architecture

## Overview

Inbound mail arrives at a public VPS and is forwarded over IPv6 to a Mailcow instance behind
CGNAT/DS-Lite. Outbound mail leaves Mailcow directly via IPv6.

```text
Internet → VPS (IPv4+IPv6, port 25) → Mailcow (IPv6, port 25, home network)
```

## Components

| Component | Role |
| --- | --- |
| `postfix` container | Accepts inbound SMTP, relays to Mailcow via IPv6 |
| `certbot` container | Obtains and renews Let's Encrypt TLS certificate via standalone HTTP |
| `postfix-exporter` container | Exposes Postfix metrics for Prometheus scraping on port 9154 |
| `transport.tmpl` | Maps relay domains to `smtp:[MAILCOW_IPV6]:PORT` |
| `helo_access` | Rejects forged HELO using own hostname |
| `header_checks` | Strips RFC-1918 addresses from `Received:` headers |

## Data flow

1. Remote MTA connects to VPS port 25
2. Postfix checks `relay_domains` and `smtpd_recipient_restrictions`
3. Transport map routes mail to `[MAILCOW_IPV6]:25`
4. Mailcow trusts the VPS IPv6 via `mynetworks` — no auth required

## TLS

Certbot runs as a sidecar container using standalone HTTP (`--standalone`, port 80) to obtain
a Let's Encrypt certificate for `RELAY_HOSTNAME`. The certificate is stored in a shared
`letsencrypt` Docker volume. On startup, `entrypoint.sh` checks whether the certificate exists
and activates the `smtpd_tls_*` directives in `main.cf` if so. Renewal runs every 12 hours;
certbot only contacts Let's Encrypt when the certificate is within 30 days of expiry.

After renewal, restart the postfix container to pick up the new certificate:

```bash
docker compose restart postfix
```

## Monitoring

`postfix-exporter` (Hsn723 fork) shares two volumes with the postfix container:

| Volume | Used for |
| --- | --- |
| `postfix-logs` | Log-based metrics (delivered, rejected, deferred rates) |
| `postfix-queue` | Queue depth via the showq socket |

Metrics are exposed at `http://<vps>:9154/metrics`. The port is bound to `127.0.0.1` by
default — open it in your firewall only for your Prometheus server.

## Key design decisions

- **No local delivery** — `mydestination` is empty; unknown recipients are rejected at SMTP time
- **No open relay** — `mynetworks` is localhost-only; only listed `relay_domains` are accepted
- **Alpine base image** — chroot disabled in `master.cf` (jail not pre-populated on Alpine)
- **Config via env vars** — `main.cf` and `transport` rendered at startup by `entrypoint.sh`
  using `envsubst`
- **TLS opt-in** — STARTTLS activates automatically once the certificate is present; the stack
  starts without TLS on first boot while certbot obtains the certificate

## DNS requirements

| Record | Value |
| --- | --- |
| MX | `mail.example.com` |
| A/AAAA | VPS IPv4/IPv6 |
| PTR | Must match `RELAY_HOSTNAME` |
| SPF | Include VPS IPv4, VPS IPv6, Mailcow home IPv6 |
