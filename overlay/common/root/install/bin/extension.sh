#! /bin/bash

# Runs as root so the code ends up owned by root; the archives' own owners and (group-writable) modes are not kept.
TAR="tar --no-same-owner --no-same-permissions"
CURL="curl --retry 3 --retry-all-errors"
export COMPOSER_ALLOW_SUPERUSER=1

NAME=$1
TYPE=$2

echo "Installing $NAME"
case $TYPE in
    skins | extensions)
        TMP=/tmp/$TYPE-$NAME.tar.gz
        MAGIC_NUMBER=$($CURL -fsS https://extdist.wmflabs.org/dist/$TYPE/ | grep -o -P "(?<=>$NAME-REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR}-)[0-9a-z]{7}(?=\.tar\.gz</a>)" | head -1)
        [ -n "$MAGIC_NUMBER" ] || { echo "No REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR} snapshot of $NAME found on extdist" >&2; exit 1; }
        $CURL -fsS -o $TMP https://extdist.wmflabs.org/dist/$TYPE/$NAME-REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR}-${MAGIC_NUMBER}.tar.gz \
        && $TAR -xzf $TMP -C /var/www/html/$TYPE \
        && rm $TMP
        ;;
    targz)
        URL=$3
        mkdir -p /var/www/html/extensions/$NAME
        $CURL -fLsS $URL | $TAR -xz --strip=1 -C /var/www/html/extensions/$NAME
        ;;
    composer)
        PKG=$3
        shift 3
        composer require $PKG "$@"
        ;;
esac
