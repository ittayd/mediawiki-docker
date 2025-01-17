ARG PHP_VERSION=7.4
ARG PHP_VARIANT=apache

# Set vars for s6 overlay
ARG S6_OVERLAY_VERSION=v2.2.0.3
ARG S6_OVERLAY_BASE_URL=https://github.com/just-containers/s6-overlay/releases/download/${S6_OVERLAY_VERSION}
ARG SOCKLOG_OVERLAY_VERSION=v3.1.2-0
ARG SOCKLOG_OVERLAY_BASE_URL=https://github.com/just-containers/socklog-overlay/releases/download/${SOCKLOG_OVERLAY_VERSION}

# Multi-stage build - See https://docs.docker.com/engine/userguide/eng-image/multistage-build

# Based on https://github.com/abraunegg/onedrive/blob/master/contrib/docker/Dockerfile-stretch, 
# PHP is based on debian:bullseye-slim (https://github.com/docker-library/docs/blob/master/php/README.md#supported-tags-and-respective-dockerfile-links)
FROM debian:stable-slim AS onedrive 

RUN apt update && \
    apt install -y build-essential curl libcurl4-openssl-dev libsqlite3-dev pkg-config git wget

RUN wget http://downloads.dlang.org/releases/2.x/2.097.0/dmd_2.097.0-0_${TARGETARCH:-amd64}.deb -O /tmp/dmd.deb && \
    dpkg -i /tmp/dmd.deb && \
	rm -f /tmp/dmd.deb

RUN git clone --depth 1 --branch v2.4.15 https://github.com/abraunegg/onedrive.git

RUN cd onedrive && \
    ./configure && \
    make clean && \
    make && \
    make install

FROM php:${PHP_VERSION}-${PHP_VARIANT} as php-armv7

ARG S6_OVERLAY_VERSION
ARG S6_OVERLAY_BASE_URL
ENV S6_OVERLAY_RELEASE="${S6_OVERLAY_BASE_URL}/s6-overlay-arm.tar.gz"
ARG SOCKLOG_OVERLAY_BASE_URL
ENV SOCKLOG_OVERLAY_RELEASE="${SOCKLOG_OVERLAY_BASE_URL}/socklog-overlay-arm.tar.gz"

FROM php:${PHP_VERSION}-${PHP_VARIANT} as php-amd64

ARG S6_OVERLAY_BASE_URL
ENV S6_OVERLAY_RELEASE="${S6_OVERLAY_BASE_URL}/s6-overlay-amd64.tar.gz"
ARG SOCKLOG_OVERLAY_VERSION
ARG SOCKLOG_OVERLAY_BASE_URL
ENV SOCKLOG_OVERLAY_RELEASE="${SOCKLOG_OVERLAY_BASE_URL}/socklog-overlay-amd64.tar.gz"

FROM php-${TARGETARCH:-amd64}${TARGETVARIANT}

ADD ${S6_OVERLAY_RELEASE} /tmp/s6-overlay.tar.gz
RUN set -eux; \
    tar xzf /tmp/s6-overlay.tar.gz -C / ; \
	rm /tmp/s6-overlay.tar.gz


# Install socklog-overlay
ADD ${SOCKLOG_OVERLAY_RELEASE} /tmp/socklog-overlay.tar.gz
RUN set -eux; \
	tar xzf /tmp/socklog-overlay.tar.gz -C / ; \
	rm /tmp/socklog-overlay.tar.gz

# System dependencies
RUN set -eux; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		certbot \
		git \
		librsvg2-bin \
		libnss3 \
		ghostscript \
		poppler-utils \
		imagemagick \
		# Required for SyntaxHighlighting
		python3 \
		python3-certbot-apache \
		cron \
	; \
	rm -rf /var/lib/apt/lists/*

# Install the PHP extensions we need
RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libicu-dev \
		libonig-dev \
		libzip-dev \
        zip \
	; \
	\
	docker-php-ext-install -j "$(nproc)" \
		intl \
		mbstring \
		mysqli \
		opcache \
		zip \
		calendar \
	; \
	\
	pecl install APCu-5.1.20; \
	docker-php-ext-enable \
		apcu \
	; \
	rm -r /tmp/pear; \
	\
	# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

# Enable Short URLs
RUN set -eux; \
	a2enmod rewrite; \
	{ \
		echo "<Directory /var/www/html>"; \
		echo "  RewriteEngine On"; \
		echo "  RewriteCond %{REQUEST_FILENAME} !-f"; \
		echo "  RewriteCond %{REQUEST_FILENAME} !-d"; \
		echo "  RewriteRule ^ %{DOCUMENT_ROOT}/index.php [L]"; \
		echo "</Directory>"; \
	} > "$APACHE_CONFDIR/conf-available/short-url.conf"; \
	a2enconf short-url

# Enable AllowEncodedSlashes for VisualEditor
RUN sed -i "s/<\/VirtualHost>/\tAllowEncodedSlashes NoDecode\n<\/VirtualHost>/" "$APACHE_CONFDIR/sites-available/000-default.conf"

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
		echo 'opcache.memory_consumption=128'; \
		echo 'opcache.interned_strings_buffer=8'; \
		echo 'opcache.max_accelerated_files=4000'; \
		echo 'opcache.revalidate_freq=60'; \
	} > /usr/local/etc/php/conf.d/opcache-recommended.ini

# SQLite Directory Setup
RUN set -eux; \
	mkdir -p /var/www/data; \
	chown -R www-data:www-data /var/www/data

# Version
ENV MEDIAWIKI_VERSION_MAJOR 1
ENV MEDIAWIKI_VERSION_MINOR 36
ENV MEDIAWIKI_VERSION_PATCH 4
ENV MEDIAWIKI_VERSION_MAIN 1.36
ENV MEDIAWIKI_VERSION 1.36.4

# MediaWiki setup
RUN set -eux; \
	fetchDeps=" \
		gnupg \
		dirmngr \
	"; \
	apt-get update; \
	apt-get install -y --no-install-recommends $fetchDeps; \
	\
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_VERSION_MAIN}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz" -o mediawiki.tar.gz; \
	curl -fSL "https://releases.wikimedia.org/mediawiki/${MEDIAWIKI_VERSION_MAIN}/mediawiki-${MEDIAWIKI_VERSION}.tar.gz.sig" -o mediawiki.tar.gz.sig; \
	export GNUPGHOME="$(mktemp -d)"; \
# gpg key from https://www.mediawiki.org/keys/keys.txt
	gpg --batch --keyserver keyserver.ubuntu.com --recv-keys \
		D7D6767D135A514BEB86E9BA75682B08E8A3FEC4 \
		441276E9CCD15F44F6D97D18C119E1A64D70938E \
		F7F780D82EBFB8A56556E7EE82403E59F9F8CD79 \
		1D98867E82982C8FE0ABC25F9B69B3109D3BB7B0 \
	; \
	gpg --batch --verify mediawiki.tar.gz.sig mediawiki.tar.gz; \
	su -s /bin/tar www-data -- -x --strip-components=1 -f mediawiki.tar.gz; \
	gpgconf --kill all; \
	rm -r "$GNUPGHOME" mediawiki.tar.gz.sig mediawiki.tar.gz; \
	# chown -R www-data:www-data extensions skins cache images; \
	a2enmod ssl; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $fetchDeps; \
	rm -rf /var/lib/apt/lists/*

COPY --from=composer:2.1.14 /usr/bin/composer /usr/local/bin/composer

COPY overlay/common/root/install /install

RUN set -eux; \
	   cd /var/www/html \
	&& ls -la \   
	&& /install/bin/extension.sh SubPageList composer mediawiki/sub-page-list \
	&& /install/bin/extension.sh MobileFrontend extensions \
	&& /install/bin/extension.sh MinervaNeue skins \
	&& /install/bin/extension.sh DataTable2 extensions \
	&& /install/bin/extension.sh DynamicPageList targz https://github.com/Universal-Omega/DynamicPageList3/archive/refs/tags/3.3.7.tar.gz \
	&& /install/bin/extension.sh Widgets extensions \
	&& /install/bin/extension.sh IFrameTag composer mediawiki/iframe-tag \
	&& /install/bin/extension.sh Drafts extensions  

COPY --chown=www-data:www-data overlay/common/www-data/ /

COPY overlay/common/root/ /
COPY overlay/debian/root/ /

RUN set -eux; \
	echo "Include /etc/apache2/mediawiki.conf" >> /etc/apache2/apache2.conf; \
	chmod 0744 /etc/services.d/*/run /etc/services.d/*/finish; \
	chmod 0600 /etc/cron.d/backup 


COPY --from=onedrive /usr/local/bin/onedrive /usr/local/bin/onedrive


ENTRYPOINT ["/overlay/bin/entrypoint.sh"]
