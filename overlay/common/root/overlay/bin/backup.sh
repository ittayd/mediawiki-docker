#! /bin/bash

WIKI_ROOT=/var/www/html
DB_ROOT=/var/www/data
DB=my_wiki.sqlite
ORIGINAL=$DB_ROOT/$DB
BACKUP_ROOT=/home/www-data/OneDrive/MediawikiBackup
DB_BACKUP=$BACKUP_ROOT/data/$DB
IMAGES_BACKUP=$BACKUP_ROOT/images
IMAGES=$WIKI_ROOT/../images
PHP=/usr/local/bin/php

function backup() {
    echo "$(date) Running backup"
    $PHP $WIKI_ROOT/maintenance/SqliteMaintenance.php --backup-to $DB_BACKUP
    $PHP $WIKI_ROOT/maintenance/dumpBackup.php --full --quiet > $BACKUP_ROOT/dump.xml
    # [ ! -e $IMAGES_BACKUP ] && mkdir $IMAGES_BACKUP
    # cd $IMAGES_BACKUP
    # $PHP $WIKI_ROOT/maintenance/dumpUploads.php --base=$(pwd) | su -s /usr/bin/xargs www-data -- cp -a -s -u -t .
}

#function wait_file() {
#    local file="$1"; shift
#    until test -e "$file"; do sleep 1; done
#}

FILE=/var/www/html/LocalSettings.php

function restore() {
    echo "Restoring DB and images"
    if [[ -e "$DB_BACKUP" && ! -e "$ORIGINAL" ]]; then
        echo "Found a $DB_BACKUP copying to $ORIGINAL"
        cp $DB_BACKUP /var/www/data/ 
        chown -R www-data:www-data $DB_ROOT
    fi

    if [ ! -e $IMAGES ]; then
        # mv $IMAGES $IMAGES.orig
        ln -s $IMAGES_BACKUP $IMAGES
        chown -h www-data:www-data $IMAGES
    fi
#    (wait_file "$FILE" && {
#        until grep -q ExtraLocalSettings $FILE; do sleep 1; done # allow to add ExtraLocalSettings.php
#        if [ ! -e $IMAGES/thumb ]; then
#            echo "Importing images from $IMAGES_BACKUP"

#            $PHP maintenance/importImages.php  $IMAGES_BACKUP
#            $PHP maintenance/rebuildall.php
#        fi
#    }) &
}

"$@"