# Installation

## Requirements

- VPS with public IPv4 and IPv6, ports 25, 465 and 587 unblocked
- `RELAY_HOSTNAME` on a Cloudflare-managed DNS zone (DNS-01 ACME challenge)
- Mailcow reachable on IPv6 port 25 from the VPS
- VPS IPv6 added to Mailcow's `mynetworks`
- PTR record for the VPS IP matching `RELAY_HOSTNAME`
- Docker with IPv6 enabled (see below)

---

## Enable Docker IPv6

Create or update `/etc/docker/daemon.json`:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00::/80"
}
```

```bash
sudo systemctl restart docker
```

---

## DNS

All records must be consistent — mismatches cause rejection.

| Record | Example |
| ------ | ------- |
| `A` | `relay.example.com → <VPS IPv4>` |
| `AAAA` | `relay.example.com → <VPS IPv6>` |
| `MX` | `example.com MX 10 relay.example.com` |
| PTR | `<VPS IPv4> → relay.example.com` (set in VPS provider console) |
| SPF | `example.com TXT "v=spf1 mx ~all"` |

`RELAY_HOSTNAME` in `.env` must exactly match the PTR record and the A/AAAA hostname.
Certbot uses the Cloudflare DNS-01 challenge — no inbound HTTP port is required, but
`RELAY_HOSTNAME`'s zone must be hosted on Cloudflare and `CLOUDFLARE_API_TOKEN` must
hold a token with `Zone:DNS:Edit` on that zone.

---

## Mailcow configuration

### Inbound relay

Internet MTAs deliver mail to the VPS on port 25. The VPS relay forwards it to Mailcow over IPv6.
Mailcow must trust the VPS as a legitimate relay source.

**Trust the VPS as relay source:**

Mailcow UI → System → Configuration → Options → Additional Postfix mynetworks → add VPS IPv6:

```text
2a01:xxxx:xxxx:xxxx::1
```

Save, then restart Postfix (Mailcow UI → Configuration → Restart services).

**Verify port 25 (or your chosen MAILCOW_PORT) is reachable over IPv6** from the VPS after the
stack is up:

```bash
nc -zv <MAILCOW_IPV6> <MAILCOW_PORT>
```

If you encounter `Network unreachable` or `Connection refused`, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

### Outbound relay

Mailcow submits outbound mail to the VPS on port 587, authenticating with SASL credentials.
The VPS relay sends it to the destination MX using its public IPv4 address.

> [!NOTE]
> This configures a global relayhost — all outbound mail routes through the VPS regardless of sender
> domain. Mailcow also offers per-domain routing via its UI; see the "See also" links at the end of
> this section.
> If any domain has a per-domain relayhost configured in Mailcow's UI, it will take precedence over
> this global setting for that domain. Remove any such entries to ensure all mail routes through the
> VPS.

**Set credentials in `.env`:**

```conf
SUBMISSION_USER=mailcow
SUBMISSION_PASS=<strong-password>
```

**Configure Mailcow to route outbound mail through the VPS:**

Add to `data/conf/postfix/extra.cf` on the Mailcow host:

```conf
relayhost = [relay.example.com]:587
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = hash:/opt/postfix/conf/sasl_passwd
smtp_sasl_security_options = noanonymous
smtp_tls_security_level = encrypt
```

Create `data/conf/postfix/sasl_passwd`:

```conf
[relay.example.com]:587 mailcow:<strong-password>
```

Postfix does not read credential files as plain text — it requires a binary hash
database compiled from the file. `postmap` performs that compilation; without it
Postfix cannot find the credentials at runtime. Hash the file and restart Mailcow:

```bash
docker compose exec postfix-mailcow postmap /opt/postfix/conf/sasl_passwd
docker compose restart postfix-mailcow
```

**See also:**

- [Mailcow: `extra.cf` overrides][mailcow-extra-overrides] — how Mailcow loads custom Postfix
  settings
- [Mailcow: per-domain relayhost via UI][mailcow-relayhost-ui] — alternative if you need
  per-domain routing instead of global

[mailcow-extra-overrides]: https://docs.mailcow.email/manual-guides/Postfix/u_e-postfix-extra_cf/
[mailcow-relayhost-ui]: https://docs.mailcow.email/manual-guides/Postfix

---

## Testing

### Inbound

```bash
swaks --to test@example.com \
      --server relay.example.com \
      --port 25 \
      --helo test.example.com
```

### Outbound

```bash
swaks --to test@example.com \
      --server relay.example.com \
      --port 587 \
      --auth LOGIN \
      --auth-user mailcow \
      --auth-password <strong-password> \
      --tls
```

Watch relay logs:

```bash
docker compose -p mailcow-vps-relay logs -f postfix
```
