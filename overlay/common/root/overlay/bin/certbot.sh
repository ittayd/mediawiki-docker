#!/usr/bin/with-contenv bash

function setup() {
    # uses SMTP_USER from the mediawiki setup if CERT_EMAIL is not present
    certbot --standalone -n certonly --no-self-upgrade --agree-tos  -m ${CERT_EMAIL:-$SMTP_USER} -d ${SERVER_DOMAIN} && \
    certbot --apache -n install --no-self-upgrade --agree-tos  -m ${CERT_EMAIL:-$SMTP_USER} -d ${SERVER_DOMAIN} --cert-name ${SERVER_DOMAIN} && \
    { APACHE_PID=$(ps ax | grep '[a]pache2' | head -1 | awk '{print $1}'); \
      [ -n "$APACHE_PID" ] && kill $APACHE_PID; }
}

function renew() {
    echo "$(date) Renew certificate"
    certbot --apache -n renew
}

"$@"