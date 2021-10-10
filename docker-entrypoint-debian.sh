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

# check a refresh token exists
if [ -f /config/refresh_token ]; then
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
  else
    echo
    echo "Please re-start start the container in interactive mode using the -it flag:"
    echo
    echo "docker run -it -v /local/config/path:/config -v /local/documents/path:/documents oznu/onedrive"
    echo
    echo "Once authorized you can re-create container with interactive mode disabled."
    echo "-------------------------------------"
    echo
    exit 1
  fi

fi

# turn on or off verbose logging
if [ "$DEBUG" = "1" ]; then
  VERBOSE=true
else
  VERBOSE=false
fi

echo "Starting onedrive client..."

onedrive --single-directory Mediawiki --syncdir=/var/www/data --verbose=${VERBOSE} --monitor

echo "Starting Apache"
apache2-foreground
