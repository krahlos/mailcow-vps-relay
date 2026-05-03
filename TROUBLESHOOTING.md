# Troubleshooting

## Port 25 Blocked (Administratively prohibited)

Many VPS providers (like Hetzner) and network operators (like myLoc) block outbound or inbound
port 25 to prevent spam. If you see `Administratively prohibited` or a timeout when testing
connectivity to your home server, you need to use a different port.

### The Port 2525 Workaround

If port 25 is blocked, use port 2525 to "tunnel" the traffic.

1. **Mailcow (Home Server):** Overwrite `SMTP_PORT=2525` in `mailcow.conf` and restart the stack.
2. **Firewalls:**
    * **Router:** Create a Port Sharing rule for **TCP 2525** to your home server.
    * **UFW:** Run `sudo ufw allow 2525/tcp`.
3. **VPS Configuration:** Update your `.env` to use the new port:

    ```bash
    MAILCOW_PORT=2525
    ```

    Then restart the relay.

---

## Docker IPv6 Connectivity Issues

If the VPS host can reach the home server but the Postfix container returns `Network unreachable`,
Docker's IPv6 routing is likely disabled.

### 1. Enable IPv6 NAT (Host)

Ensure `/etc/docker/daemon.json` on the VPS has `ip6tables` enabled:

```json
{
  "ipv6": true,
  "fixed-cidr-v6": "fd00::/80",
  "ip6tables": true
}
```

Restart Docker: `sudo systemctl restart docker`.

### 2. Enable IPv6 in Compose

Docker Compose networks do not enable IPv6 by default. Ensure your `docker-compose.yml` includes
the network configuration:

```yaml
networks:
  default:
    enable_ipv6: true
    ipam:
      config:
        - subnet: fd00:dead:beef::/64
```

---

## Testing Connectivity

Always test connectivity from **inside** the container to ensure the entire stack is working:

```bash
docker exec -it mailcow-vps-relay-postfix nc -zv [MAILCOW_IPV6] [MAILCOW_PORT]
```

If it says `open` or `succeeded`, the path is clear.
