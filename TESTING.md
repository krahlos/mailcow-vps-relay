# Testing

## Local Setup

1. `cp .env.example .env`
2. Set `MAILCOW_IPV6=127.0.0.1`
3. `docker-compose up -d --no-deps postfix`

---

## Outbound Relay (Submission)

Verify SASL authentication on port 587.

**Command:**

```bash
swaks --to user@example.com --server 127.0.0.1 --port 587 \
      --auth LOGIN --auth-user mailcow --auth-password change-me \
      --quit-after AUTH --tls-protocol none
```

**Expected Output:**

```text
<-  250-AUTH PLAIN LOGIN
 -> AUTH LOGIN
<-  334 VXNlcm5hbWU6
 -> bWFpbGNvdw==
<-  334 UGFzc3dvcmQ6
 -> Y2hhbmdlLW1l
<-  235 2.7.0 Authentication successful
```

*Note: `--tls-protocol none` only works if `smtpd_tls_security_level` is set to `may`. Production
requires STARTTLS.*

---

## Inbound Relay

Verify Postfix accepts mail for relay domains.

**Command:**

```bash
swaks --to test@example.com --server 127.0.0.1 --port 25
```

**Expected Output:**

```text
<-  220 relay.example.com ESMTP Postfix
 -> EHLO ...
<-  250-relay.example.com
...
 -> MAIL FROM:<...>
<-  250 2.1.0 Ok
 -> RCPT TO:<test@example.com>
<-  250 2.1.5 Ok
```
