#! /bin/bash

WIKI_ROOT=/var/www/html
BACKUP=/home/www-data/OneDrive/MediawikiBackup/data/my_wiki.sqlite

function backup() {
    /usr/local/bin/php $WIKI_ROOT/maintenance/SqliteMaintenance.php --backup-to $BACKUP
}

function restore() {
    [ -e "$BACKUP" ] && cp $BACKUP /var/www/data/ && chown -R www-data:www-data /var/www/data
}

"$@"