#! /bin/bash

function wait_file() {
    local file="$1"; shift
    until test -e "$file"; do sleep 1; done
}

FILE=/var/www/html/LocalSettings.php

(wait_file "$FILE" && {
    require="require 'ExtraLocalSettings.php';"
    if ! grep -q "$require"; then
        echo "$require" >> "$FILE"
    fi
}) &

apache2-foreground
