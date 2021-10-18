#! /bin/bash

WIKI_ROOT=/var/www/html
DB_ROOT=/var/www/data
DB=my_wiki.sqlite
ORIGINAL=$DB_ROOT/$DB
BACKUP=/home/www-data/OneDrive/MediawikiBackup/data/$DB

function backup() {
    /usr/local/bin/php $WIKI_ROOT/maintenance/SqliteMaintenance.php --backup-to $BACKUP
}

function restore() {
    [[ -e "$BACKUP" && ! -e "$ORIGINAL" ]] && cp $BACKUP /var/www/data/ && chown -R www-data:www-data $DB_ROOT
}

"$@"