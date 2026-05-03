# Architecture

## Overview

```text
Inbound:  Internet ──(IPv4, port 25)──▶ VPS ──(IPv6, port 25)──▶ Mailcow
Outbound: Mailcow ──(IPv6, port 587)──▶ VPS ──(IPv4, port 25)──▶ Internet
```

Inbound mail arrives at a public VPS and is forwarded over IPv6 to a Mailcow instance behind
CGNAT/DS-Lite. Outbound mail is submitted by Mailcow to the VPS on port 587 (SASL auth + TLS),
then delivered to the destination MX using the VPS public IPv4 address.

## Components

| Component | Role |
| --------- | ---- |
| `postfix` | Inbound and outbound SMTP relay for Mailcow |
| `certbot` | Obtains and renews Let's Encrypt TLS cert via DNS-01 |
| `postfix-exporter` | Exposes Postfix metrics on port 9154 |
| `transport.tmpl` | Maps relay domains to `smtp:[MAILCOW_IPV6]:PORT` |
| `helo_access` | Rejects forged HELO using own hostname |
| `header_checks` | Strips RFC-1918 addresses from `Received:` headers |

## Data flow

### Inbound

1. Remote MTA connects to VPS port 25
2. Postfix checks `relay_domains` and `smtpd_recipient_restrictions`
3. Transport map routes mail to `[MAILCOW_IPV6]:25`
4. Mailcow trusts the VPS IPv6 via `mynetworks` — no auth required

### Outbound

1. Mailcow connects to VPS port 587, authenticates with SASL (PLAIN/LOGIN)
2. Postfix verifies credentials against sasldb
   (`smtpd_relay_restrictions = permit_sasl_authenticated, reject`)
3. Postfix delivers to destination MX via VPS public IPv4

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
- **No open relay** — `mynetworks` localhost-only; only listed `relay_domains` accepted;
  submission listeners require SASL auth
- **Alpine base** — chroot disabled in `master.cf` (jail not pre-populated on Alpine)
- **Config via env vars** — `main.cf` and `transport` rendered at startup by `entrypoint.sh` via `envsubst`
- **TLS opt-in** — STARTTLS activates once cert is present; stack starts without TLS on first boot
- **SASL via sasldb** — credentials created at container startup from `SUBMISSION_USER`/`SUBMISSION_PASS`
  env vars; no persistent credential file needed in the image

## DNS requirements

| Record | Value |
| ------ | ----- |
| MX | `relay.example.com` |
| A/AAAA | VPS IPv4/IPv6 |
| PTR | Must match `RELAY_HOSTNAME` |
| SPF | Include VPS IPv4, VPS IPv6, Mailcow home IPv6 |

## Protocols

| Protocol | Port | Direction | Purpose |
| -------- | ---- | --------- | ------- |
| SMTP | 25 | server ↔ server | Deliver mail between MTAs |
| SMTP submission | 587 | client → server | Send mail from mail client or app (STARTTLS) |
| SMTPS | 465 | client → server | Send mail from mail client or app (implicit TLS) |
| IMAP | 143 / 993 | client ↔ server | Read and sync mailbox (mail stays on server) |
| POP3 | 110 / 995 | client ← server | Download mailbox (mail removed from server) |

This project handles SMTP only. IMAP and POP3 connect directly to Mailcow and are not routed
through the VPS relay.
