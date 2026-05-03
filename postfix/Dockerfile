FROM alpine:3.21

RUN apk add --no-cache \
    postfix \
    ca-certificates \
    gettext \
    cyrus-sasl \
    cyrus-sasl-login \
    && mkdir -p /etc/sasl2

COPY entrypoint.sh /entrypoint.sh
COPY main.cf /etc/postfix/main.cf.tmpl
COPY master.cf /etc/postfix/master.cf
COPY sasl/smtpd.conf /etc/sasl2/smtpd.conf
RUN chmod +x /entrypoint.sh

EXPOSE 25
EXPOSE 587
EXPOSE 465

ENTRYPOINT ["/entrypoint.sh"]
