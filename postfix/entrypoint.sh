#!/bin/bash
set -e

# Render main.cf from template
envsubst < /etc/postfix/main.cf.tmpl > /etc/postfix/main.cf

# Render transport map from template and build hash
envsubst < /etc/postfix/transport.tmpl > /etc/postfix/transport
postmap /etc/postfix/transport

# Build helo_access hash map
postmap /etc/postfix/helo_access

exec /usr/sbin/postfix start-fg
