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

# turn on or off verbose logging
if [ "$DEBUG" = "1" ]; then
  VERBOSE=true
else
  VERBOSE=false
fi

# check a refresh token exists
if [ -f ~/.config/onedrive/refresh_token ]; then
  echo "Found onedrive refresh token..."
else
  echo
  echo "-------------------------------------"
  echo "ONEDRIVE LOGIN REQUIRED"
  echo "-------------------------------------"
  echo "To use this container you must authorize the OneDrive Client."

  if [ -t 0 ] ; then
    echo "-------------------------------------"
    echo
    onedrive --verbose=${VERBOSE} --single-directory MediawikiBackup --synchronize
    exit 0
  else
    echo
    echo "Please re-start start the container in interactive mode using the -it flag:"
    echo
    echo "docker run -it $(hostname)"
    echo
    echo "Once authorized you can re-create container with interactive mode disabled."
    echo "-------------------------------------"
    echo
    exit 1
  fi

fi


echo "Starting onedrive client..."

onedrive --verbose=${VERBOSE} --single-directory MediawikiBackup --monitor > /var/log/onedrive/console.log-.log 2>&1 &

echo "Starting Apache..."
apache2-foreground > /var/log/apache2/console.log 2>&1
