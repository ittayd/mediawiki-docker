#! /bin/bash

INI=/var/www/html/ExtraLocalConfig.ini
[ -e "$INI" ] && exit 0

read -r -p "Enter google email username: " SMTP_USER
read -r -s -p "Enter google email password: " SMTP_PASS

cat << EOF > $INI
smtp_user = '$SMTP_USER'
smtp_pass = '$SMTP_PASS'
EOF
