#! /bin/bash

# The backup runs in two steps under different users, so a compromised web process (www-data)
# can at worst produce a bad snapshot; it can't touch what was already published or the OneDrive token.
#   snapshot (www-data): dump the database and pages into $STAGING
#   publish  (onedrive): validate the staged snapshot and the images, then copy them into the OneDrive folder

WIKI_ROOT=/var/www/html
DB_ROOT=/var/www/data
DB=my_wiki.sqlite
ORIGINAL=$DB_ROOT/$DB
IMAGES=/var/www/images
STAGING=/var/backups/wiki-staging
BACKUP_ROOT=/home/onedrive/OneDrive/MediawikiBackup
LATEST=$BACKUP_ROOT/latest
DAILY=$BACKUP_ROOT/daily
IMAGES_BACKUP=$BACKUP_ROOT/images
LEGACY_DB_BACKUP=$BACKUP_ROOT/data/$DB
STATE=/home/onedrive/.local/state/wiki-backup
ONEDRIVE_DB=/home/onedrive/.config/onedrive/items.sqlite3
PHP=/usr/local/bin/php

# Reject a snapshot that has this many percent fewer pages than the last published one
MAX_PAGE_DROP_PERCENT=${BACKUP_MAX_PAGE_DROP_PERCENT:-10}
# Reject a backup run where more than this many already backed up images were modified.
# MediaWiki only rewrites an existing file when a new version of it is uploaded.
MAX_CHANGED_IMAGES=${BACKUP_MAX_CHANGED_IMAGES:-10}
# Only affects the local copy; deletions are never propagated to OneDrive
DAILY_LOCAL_RETENTION_DAYS=14
IMAGES_EXCLUDES=(--exclude=/thumb/ --exclude=/temp/ --exclude=/lockdir/)

# Certbot renews 30 days before expiry, so a certificate this close to expiring means renewal is failing
CERT_MIN_DAYS=14

# HEALTHCHECK_URL is a dead man's switch (e.g. https://hc-ping.com/<uuid>): it gets pinged after a successful
# backup whose health checks pass, and "$HEALTHCHECK_URL/fail" otherwise, so both failures and silence alert.
function ping() {
    local suffix="$1" message="$2"
    [ -n "$HEALTHCHECK_URL" ] || return 0
    curl -fsS -m 10 --retry 3 --data-raw "$message" "$HEALTHCHECK_URL$suffix" > /dev/null \
        || echo "$(date) Could not reach the healthcheck URL" >&2
}

function reject() {
    echo "$(date) Backup REJECTED, nothing was published: $*" >&2
    ping /fail "$*"
    exit 1
}

function run() {
    echo "$(date) Running backup"
    local problems=() problem
    # Before publishing, since it checks the database published by the previous run
    problem=$(check_upload) || problems+=("$problem")

    su -s /overlay/bin/backup.sh www-data -- snapshot \
        || { echo "$(date) Backup REJECTED, nothing was published: snapshot failed" >&2; ping /fail "snapshot failed"; return 1; }
    su -s /overlay/bin/backup.sh onedrive -- publish || return 1

    problem=$(check_site) || problems+=("$problem")
    if (( ${#problems[@]} )); then
        echo "$(date) Backup published, but a health check failed: ${problems[*]}" >&2
        ping /fail "backup published, but: ${problems[*]}"
        return 1
    fi
    ping "" "backup published, health checks passed"
}

# The OneDrive client runs separately; make sure what was published actually reaches OneDrive
function check_upload() {
    s6-svstat /var/run/s6/services/onedrive 2>/dev/null | grep -q '^up' || { echo "the OneDrive uploader is not running;"; return 1; }
    [ -f "$LATEST/$DB" ] || return 0
    local local_mtime remote_mtime
    local_mtime=$(stat -c %Y "$LATEST/$DB")
    # Give a fresh file time to upload
    (( $(date +%s) - local_mtime > 600 )) || return 0
    # The client keeps its database exclusively locked while it runs, so read a copy
    local copy
    copy=$(mktemp -d) || { echo "cannot create a temporary directory;"; return 1; }
    cp "$ONEDRIVE_DB" "$copy/items.sqlite3" 2>/dev/null
    [ -f "$ONEDRIVE_DB-wal" ] && cp "$ONEDRIVE_DB-wal" "$copy/items.sqlite3-wal"
    remote_mtime=$(sqlite3 "$copy/items.sqlite3" \
        "SELECT i.mtime FROM item i JOIN item p ON p.driveId = i.driveId AND p.id = i.parentId
         WHERE i.name = '$DB' AND p.name = 'latest';" 2>/dev/null | head -1)
    rm -rf "$copy"
    [ -n "$remote_mtime" ] && remote_mtime=$(date -d "$remote_mtime" +%s 2>/dev/null)
    [ -n "$remote_mtime" ] && (( remote_mtime >= local_mtime - 2 )) \
        || { echo "the database published at $(date -d "@$local_mtime" '+%F %R') has not reached OneDrive;"; return 1; }
}

# The backup runs PHP from the command line, so also check that Apache serves the wiki
function check_site() {
    local domain=${SERVER_DOMAIN:-$(awk '$1 == "ServerName" { print $2; exit }' /etc/apache2/mediawiki.conf 2>/dev/null)}
    [ -n "$domain" ] || { echo "cannot tell the wiki's domain;"; return 1; }
    local insecure=() body
    [ -n "$SELF_SIGNED_CERT" ] && insecure=(-k)
    body=$(curl -fsSL -m 30 "${insecure[@]}" --resolve "$domain:443:127.0.0.1" "https://$domain/" 2>&1) \
        || { echo "the main page failed: $(head -c 200 <<< "$body");"; return 1; }
    # Errors come back as HTTP 500 and fail curl. A private wiki shows anonymous visitors a "login required"
    # page instead of the article, so only check that MediaWiki rendered a page.
    grep -q '"wgAction":"view"' <<< "$body" || { echo "the main page is not a MediaWiki page;"; return 1; }

    # Through DNS and the public IP, so a moved DNS record or reserved IP shows up too
    body=$(curl -fsSL -m 30 "${insecure[@]}" "https://$domain/" 2>&1) \
        || { echo "the wiki works locally but not at https://$domain/: $(head -c 200 <<< "$body");"; return 1; }
    grep -q '"wgAction":"view"' <<< "$body" || { echo "https://$domain/ does not serve this wiki;"; return 1; }

    [ -n "$SELF_SIGNED_CERT" ] && return 0
    openssl s_client -connect 127.0.0.1:443 -servername "$domain" < /dev/null 2>/dev/null \
        | openssl x509 -noout -checkend $(( CERT_MIN_DAYS * 86400 )) > /dev/null \
        || { echo "the certificate expires within $CERT_MIN_DAYS days;"; return 1; }
}

function snapshot() {
    umask 027
    rm -f "$STAGING/$DB" "$STAGING/dump.xml"
    $PHP $WIKI_ROOT/maintenance/run.php SqliteMaintenance --backup-to "$STAGING/$DB" \
        && $PHP $WIKI_ROOT/maintenance/run.php dumpBackup --full --quiet > "$STAGING/dump.xml"
}

function publish() {
    umask 077
    mkdir -p "$STATE" "$LATEST" "$DAILY" "$IMAGES_BACKUP"
    work=$(mktemp -d "$STATE/work.XXXXXX") || reject "cannot create a work directory"
    trap 'rm -rf "$work"' EXIT

    # Validate a private copy, so the files can't be swapped between validation and publishing
    for f in "$DB" dump.xml; do
        [ -f "$STAGING/$f" ] && [ ! -L "$STAGING/$f" ] || reject "$STAGING/$f is missing or not a regular file"
        cp -- "$STAGING/$f" "$work/$f" || reject "cannot copy $STAGING/$f"
    done

    local check pages last_pages
    check=$(sqlite3 "$work/$DB" 'PRAGMA quick_check;' 2>&1)
    [ "$check" = ok ] || reject "database integrity check failed: $check"
    pages=$(sqlite3 "$work/$DB" 'SELECT COUNT(*) FROM page;' 2>&1)
    [[ "$pages" =~ ^[0-9]+$ ]] && [ "$pages" -gt 0 ] || reject "cannot count pages: $pages"
    last_pages=$(cat "$STATE/page_count" 2>/dev/null)
    if [[ "$last_pages" =~ ^[0-9]+$ ]] && (( pages * 100 < last_pages * (100 - MAX_PAGE_DROP_PERCENT) )); then
        reject "page count dropped from $last_pages to $pages"
    fi
    tail -c 1024 "$work/dump.xml" | grep -q '</mediawiki>' || reject "the XML dump is incomplete"

    # Skipped on the first run, since a freshly restored images folder may differ only in timestamps
    if [ -n "$last_pages" ]; then
        local changes changed
        changes=$(rsync -a --no-links --dry-run --out-format='%i %n' "${IMAGES_EXCLUDES[@]}" "$IMAGES/" "$IMAGES_BACKUP/") \
            || reject "cannot compare images"
        changed=$(awk '/^>f/ && !/^>f\+\+\+/ { n++ } END { print n + 0 }' <<< "$changes")
        (( changed <= MAX_CHANGED_IMAGES )) || reject "$changed existing images were modified since the last backup"
    fi

    # First, so that a failure here still leaves nothing published
    rsync -a --no-links "${IMAGES_EXCLUDES[@]}" "$IMAGES/" "$IMAGES_BACKUP/" || reject "cannot copy images"

    cp "$work/$DB" "$LATEST/.$DB.new" && mv -f "$LATEST/.$DB.new" "$LATEST/$DB" || reject "cannot publish the database"
    gzip -c "$work/dump.xml" > "$LATEST/.dump.xml.gz.new" && mv -f "$LATEST/.dump.xml.gz.new" "$LATEST/dump.xml.gz" \
        || reject "cannot publish the XML dump"

    # Read from the web root, not from staging: LocalSettings.php is owned by root, so www-data can't plant code in the backup
    local settings=$WIKI_ROOT/LocalSettings.php
    if [ -f "$settings" ] && [ ! -L "$settings" ]; then
        cp -- "$settings" "$work/LocalSettings.php" || reject "cannot copy $settings"
        $PHP -l "$work/LocalSettings.php" > /dev/null 2>&1 || reject "$settings has a PHP syntax error"
        cp "$work/LocalSettings.php" "$LATEST/.LocalSettings.php.new" && mv -f "$LATEST/.LocalSettings.php.new" "$LATEST/LocalSettings.php" \
            || reject "cannot publish LocalSettings.php"
    fi

    local today
    today="$DAILY/$(date +%F)"
    if [ ! -d "$today" ]; then
        mkdir "$today.new" \
            && gzip -c "$work/$DB" > "$today.new/$DB.gz" \
            && cp "$LATEST/dump.xml.gz" "$today.new/dump.xml.gz" \
            && { [ ! -f "$work/LocalSettings.php" ] || cp "$work/LocalSettings.php" "$today.new/LocalSettings.php"; } \
            && mv "$today.new" "$today" \
            || reject "cannot create the daily snapshot"
    fi

    echo "$pages" > "$STATE/page_count"
    find "$DAILY" -mindepth 1 -maxdepth 1 -type d -mtime +$DAILY_LOCAL_RETENTION_DAYS -exec rm -rf {} +

    echo "$(date) Backup published ($pages pages)"
}

function restore() {
    echo "Restoring DB and images"
    if [ ! -e "$ORIGINAL" ]; then
        for candidate in "$LATEST/$DB" "$LEGACY_DB_BACKUP"; do
            if [ -e "$candidate" ]; then
                echo "Found $candidate, copying to $ORIGINAL"
                cp "$candidate" "$ORIGINAL"
                chown -R www-data:www-data $DB_ROOT
                break
            fi
        done
    fi

    if [ ! -e "$WIKI_ROOT/LocalSettings.php" ] && [ -f "$LATEST/LocalSettings.php" ]; then
        echo "Found $LATEST/LocalSettings.php, copying to $WIKI_ROOT"
        install -o root -g root -m 0644 "$LATEST/LocalSettings.php" "$WIKI_ROOT/LocalSettings.php"
    fi

    if [ ! -e $IMAGES ]; then
        mkdir -p $IMAGES
        if [ -d "$IMAGES_BACKUP" ]; then
            echo "Copying images from $IMAGES_BACKUP"
            cp -a "$IMAGES_BACKUP/." $IMAGES/
        fi
        chown -R www-data:www-data $IMAGES
        # The OneDrive client downloads files readable only by itself, and once they belong to www-data the backup can't read them
        chmod -R u+rwX,go+rX,go-w $IMAGES
    fi
}

"$@"
