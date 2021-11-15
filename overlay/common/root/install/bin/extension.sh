#! /bin/bash

echo "Installing $1"
TMP=/tmp/extension-$1.tar.gz
MAGIC_NUMBER=$(curl -s https://extdist.wmflabs.org/dist/extensions/ | grep -o -P "(?<=$1-REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR}-)[0-9a-z]{7}(?=.tar.gz)" | head -1)
curl -s -o $TMP https://extdist.wmflabs.org/dist/extensions/$1-REL${MEDIAWIKI_VERSION_MAJOR}_${MEDIAWIKI_VERSION_MINOR}-${MAGIC_NUMBER}.tar.gz \
&& tar -xzf $TMP -C /var/www/html/extensions \
&& rm $TMP
