FROM alpine:3.21

RUN apk add --no-cache \
    postfix \
    ca-certificates \
    gettext

COPY entrypoint.sh /entrypoint.sh
COPY main.cf /etc/postfix/main.cf.tmpl
COPY master.cf /etc/postfix/master.cf
RUN chmod +x /entrypoint.sh

EXPOSE 25

ENTRYPOINT ["/entrypoint.sh"]
