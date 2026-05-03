# Installation

## Requirements

- VPS with public IPv4 and IPv6, ports 25 and 80 unblocked
- Mailcow reachable on IPv6 port 25 from the VPS
- VPS IPv6 added to Mailcow's `mynetworks`
- PTR record for the VPS IP matching `RELAY_HOSTNAME`
- Docker with IPv6 enabled (see below)

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
Certbot uses HTTP-01 and requires the A record to resolve to the VPS.

## Mailcow configuration

**Trust the VPS as relay source:**

Mailcow UI → System → Configuration → Options → Additional Postfix mynetworks → add VPS IPv6:

```text
2a01:xxxx:xxxx:xxxx::1
```

Save, then restart Postfix (Mailcow UI → Configuration → Restart services).

**Verify port 25 is reachable over IPv6** from the VPS after the stack is up:

```bash
nc -zv <MAILCOW_IPV6> 25
```

## Testing

```bash
swaks --to test@example.com \
      --server relay.example.com \
      --port 25 \
      --helo test.example.com
```

Watch relay logs:

```bash
docker compose -p mailcow-vps-relay logs -f postfix
```
