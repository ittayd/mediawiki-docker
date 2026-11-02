#!/bin/bash
set -euo pipefail

cd "$(dirname "$(readlink -f "$BASH_SOURCE")")"

mediawikiReleases=( "$@" )
if [ ${#mediawikiReleases[@]} -eq 0 ]; then
	mediawikiReleases=( 1.*/ )
fi
mediawikiReleases=( "${mediawikiReleases[@]%/}" )

declare -A phpVersion=(
	[default]='8.3'
)

# Lowest patch release of each PHP branch that is not affected by known critical CVEs
# (CVE-2026-109618 / CVE-2026-109619). The build fails on anything older.
declare -A phpMinVersion=(
	[8.2]='8.2.35'
	[8.3]='8.3.36'
	[8.4]='8.4.27'
	[8.5]='8.5.12'
)

declare -A peclVersions=(
	[APCu]="5.1.28"
)

function mediawiki_version() {
	git ls-remote --sort=version:refname --tags https://github.com/wikimedia/mediawiki.git \
		| cut -d/ -f3 \
		| tr -d '^{}' \
		| grep -E "^$1\.[0-9]+$" \
		| tail -1
}

declare -A variantExtras=(
	[apache]='\n# Enable Short URLs\nRUN set -eux; \\\n\ta2enmod rewrite; \\\n\t{ \\\n\t\techo \"<Directory /var/www/html>\"; \\\n\t\techo \"  RewriteEngine On\"; \\\n\t\techo \"  RewriteCond %{REQUEST_FILENAME} !-f\"; \\\n\t\techo \"  RewriteCond %{REQUEST_FILENAME} !-d\"; \\\n\t\techo \"  RewriteRule ^ %{DOCUMENT_ROOT}/index.php [L]\"; \\\n\t\techo \"</Directory>\"; \\\n\t} > \"$APACHE_CONFDIR/conf-available/short-url.conf\"; \\\n\ta2enconf short-url\n\n# Enable AllowEncodedSlashes for VisualEditor\nRUN sed -i \"s/<\\/VirtualHost>/\\tAllowEncodedSlashes NoDecode\\n<\\/VirtualHost>/\" \"$APACHE_CONFDIR/sites-available/000-default.conf\"'
)
declare -A variantCmds=(
	[apache]='/docker-entrypoint.sh'
)
declare -A variantBases=(
	[apache]='debian'
)

for mediawikiRelease in "${mediawikiReleases[@]}"; do
	mediawikiReleaseDir="$mediawikiRelease"
	mediawikiVersion="$(mediawiki_version $mediawikiRelease)"
	php=${phpVersion[$mediawikiRelease]-${phpVersion[default]}}
	phpMin=${phpMinVersion[$php]}

	for variant in apache; do
		dir="$mediawikiReleaseDir/$variant"
		mkdir -p "$dir"

		extras="${variantExtras[$variant]}"
		cmd="${variantCmds[$variant]}"
		base="${variantBases[$variant]}"

 		IFS=. read major minor patch <<< "$mediawikiVersion"
		sed -r \
			-e 's!%%MEDIAWIKI_VERSION_MAJOR%%!'"$major"'!g' \
			-e 's!%%MEDIAWIKI_VERSION_MINOR%%!'"$minor"'!g' \
			-e 's!%%MEDIAWIKI_VERSION_PATCH%%!'"$patch"'!g' \
			-e 's!%%PHP_VERSION%%!'"$php"'!g' \
			-e 's!%%PHP_MIN_VERSION%%!'"$phpMin"'!g' \
			-e 's!%%VARIANT%%!'"$variant"'!g' \
			-e 's!%%APCU_VERSION%%!'"${peclVersions[APCu]}"'!g' \
			-e 's@%%VARIANT_EXTRAS%%@'"$extras"'@g' \
			-e 's!%%CMD%%!'"$cmd"'!g' \
			"Dockerfile-${base}.template" > "$dir/Dockerfile"
	done
done
