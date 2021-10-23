#! /bin/bash

INI=/var/www/html/ExtraLocalConfig.ini
if [ ! -e "$INI" ]; then

    [ -z "$SMTP_USER" ] && read -r -p "Enter google email username: " SMTP_USER
    [ -z "$SMTP_PASS" ] && read -r -s -p "Enter google email password: " SMTP_PASS

    cat <<- EOF > $INI
smtp_user = '$SMTP_USER'
smtp_pass = '$SMTP_PASS'
EOF
fi

if [ ! -e /etc/apache2/ssl.crt ]; then
    [ -z "$SERVER_DOMAIN" ] && read -r -p "Enter the server domain: " SERVER_DOMAIN
    eval "cat <<EOF
$(</root/ssl.csr.tpl)
EOF
" 2> /dev/null > /root/ssl.csr

    openssl req -new -nodes -x509 -days 36500 -keyout /etc/apache2/ssl.key -out /etc/apache2/ssl.crt -config /root/ssl.csr
fi
