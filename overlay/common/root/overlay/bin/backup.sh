#! /bin/bash

WIKI_ROOT=/var/www/html
DB_ROOT=/var/www/data
DB=my_wiki.sqlite
ORIGINAL=$DB_ROOT/$DB
BACKUP_ROOT=/home/www-data/OneDrive/MediawikiBackup
DB_BACKUP=$BACKUP_ROOT/data/$DB
IMAGES_BACKUP=$BACKUP_ROOT/images
IMAGES=$WIKI_ROOT/images
PHP=/usr/local/bin/php

function backup() {
    $PHP $WIKI_ROOT/maintenance/SqliteMaintenance.php --backup-to $DB_BACKUP
    [ ! -e $IMAGES_BACKUP ] && mkdir $IMAGES_BACKUP
    $PHP $WIKI_ROOT/maintenance/dumpUploads.php | xargs cp -u -t $IMAGES_BACKUP
}

function wait_file() {
    local file="$1"; shift
    until test -e "$file"; do sleep 1; done
}

FILE=/var/www/html/LocalSettings.php

function restore() {
    [[ -e "$BACKUP" && ! -e "$ORIGINAL" ]] && cp $BACKUP /var/www/data/ && chown -R www-data:www-data $DB_ROOT

    (wait_file "$FILE" && {
        until grep -q ExtraLocalSettings $FILE; do sleep 1; done # allow to add ExtraLocalSettings.php
        if [ ! -e $IMAGES/thumb ]; then
            $PHP maintenance/importImages.php  $IMAGES_BACKUP
            $PHP maintenance/update.php
            $PHP maintenance/rebuildall.php
        fi
    }) &
}

"$@"