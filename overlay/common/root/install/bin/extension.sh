#! /bin/bash

function run() {
    local cmd=$(which $1)
    shift
    su -s $cmd www-data -- "$@"
}

NAME=$1
TYPE=$2

echo "Installing $NAME"
case $TYPE in
    skins | extensions)
        TMP=/tmp/$TYPE-$NAME.tar.gz
        MAGIC_NUMBER=$(curl -s https://extdist.wmflabs.org/dist/$TYPE/ | grep -o -P "(?<=>$NAME-REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR}-)[0-9a-z]{7}(?=\.tar\.gz</a>)" | head -1)
        curl -s -o $TMP https://extdist.wmflabs.org/dist/$TYPE/$NAME-REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR}-${MAGIC_NUMBER}.tar.gz \
        && run tar -xzf $TMP -C /var/www/html/$TYPE \
        && rm $TMP
        ;;
    targz)
        URL=$3
        run mkdir -p /var/www/html/extensions/$NAME 
        curl -Ls $URL | run tar xz --strip=1 -C /var/www/html/extensions/$NAME
        ;;
    composer)
        PKG=$3
        run composer require $PKG
        ;;
esac
