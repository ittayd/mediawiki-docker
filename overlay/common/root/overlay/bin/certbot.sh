#!/usr/bin/with-contenv bash

function setup() {
    # uses SMTP_USER from the mediawiki setup if CERT_EMAIL is not present
    local email=${CERT_EMAIL:-$SMTP_USER}
    while [[ "$email" != *@*.* ]]; do
        [ -t 0 ] || { echo "CERT_EMAIL is not a valid email address: '$email'" >&2; return 1; }
        read -r -p "Enter an email address for Let's Encrypt expiry notices: " email
    done
    certbot --standalone -n certonly --agree-tos -m "$email" -d "$SERVER_DOMAIN" && \
    certbot --apache -n install --agree-tos -m "$email" -d "$SERVER_DOMAIN" --cert-name "$SERVER_DOMAIN" && \
    { APACHE_PID=$(ps ax | grep '[a]pache2' | head -1 | awk '{print $1}'); \
      [ -n "$APACHE_PID" ] && kill $APACHE_PID; }
}

function renew() {
    echo "$(date) Renew certificate"
    certbot --apache -n renew
}

"$@"