Do not edit the `Dockerfile`s directly. Changes should be made in the `Dockerfile-*.template` files and applied by running `update.sh`.

`bash.exe update.sh; docker build --pull -t ittayd/mediawiki:latest -f .\1.43\apache\Dockerfile .`
`docker scout cves ittayd/mediawiki:latest`
`docker image push ittayd/mediawiki:latest`

Always build with `--pull`: PHP and Debian security fixes arrive through the `php:8.3-apache-trixie` base image, and a cached old copy of it won't have them. The build refuses to continue on a PHP older than the minimum set in `update.sh`. Rebuild and redeploy at least monthly, and right away when a PHP or MediaWiki security release is announced (subscribe to the `mediawiki-announce` mailing list).


After building the image, run it with -it, it needs to:
* ask for username & password to send emails through google
* get a onedrive token interactively. 
* create certs
** LE has rate limiting, so if trying running an image multiple times, use SELF_SIGNED_CERT=1 in the environment to avoid being blocked.
*** in that case /etc/letsencrypt and /etc/apache2/mediawiki.conf from the old container will work. They can be copied over while onedrive waits for the token

Also, port forward, if needed, to port 80. 

Can pass environment varialbes:
`docker run -e SMTP_USER=<gmail user> -e SMTP_PASS=<password> -e SERVER_DOMAIN=<domain> -e HEALTHCHECK_URL=https://hc-ping.com/<uuid> --log-opt max-size=4m --log-opt max-file=3 --restart unless-stopped --security-opt no-new-privileges --memory 1g --pids-limit 512 -it -p 80:80 -p 443:443 --name mediawiki ittayd/mediawiki:latest`
* onedrive takes some time to finish syncing. wait for `DONE`

Can do `docker exec -it mediawiki bash` to enter the container. 
* Check whether the DB file is copied to /var/www/data before doing the browser setup

The web installer (`/mw-config`) is blocked unless the container is created with `-e ALLOW_WEB_INSTALLER=1`: until `LocalSettings.php` exists, anyone who finds it can run it. Only allow it for a fresh install, and recreate the container without it afterwards. Upgrades don't need it (see below).

Load the URL with a full IP (not localhost or 127.0.0.1). These are my settings in the setup
* Page 1
** Wiki Language: he
* Page 3
** Database type: SQLite
** If DB is found, upgrade, and then choose to regenerate LocalSettings.php
* Page 4
** Name of wiki: בית
** Administrator account: my login
** Share data about this installation with MediaWiki developers: Uncheck
* Page 5
** User rights profile: private wiki
** Enable user talk page notification
** Enable watchlist notification
** Skins > Timeless : Use this skin as default
** Extensions: WikiEditor, VisualEditor, CodeEditor, CategoryTree, InputBox, ParserFunctions, Scribunto, SyntaxHighlight_GeSHi, TemplateData, PdfHandler, Gadgets, MobileFrontend, SubPageList, TextExtracts, DataTable2, Widgets, DynamicPageList, IFrameTag, 
*** MobileFrontend - for mobile view
*** SubPageList - for recipies
** Enable file uploads
** deleted images in /var/www/images/deleted

Copy resulting LocalSettings.php file: `docker cp LocalSettings.php mediawiki:/var/www/html/LocalSettings.php`

Note: a check will add a 'require ExtraLocalSettings.php' to LocalSettings to load extra settings

The logo (`$wgLogos` points to `resources/assets/wiki.png`) is copied into the image from `overlay/common/www-data/var/www/html/resources/assets/wiki.png`. That file is not in git, so put it there before building; an image built without it has no logo.

Instead of the browser upgrade, an existing LocalSettings.php can be copied in and the schema upgraded with `docker exec -u www-data mediawiki php /var/www/html/maintenance/run.php update --quick`.
SubPageList must be loaded with `wfLoadExtension( 'SubPageList' );`; the old `require_once ".../SubPageList.php";` line fails because that file no longer exists.
`LocalSettings.php` is backed up to `latest/` (and `daily/`) and restored into a new container that doesn't have one. It contains the wiki's secret keys, as sensitive as the database next to it. The Gmail app password (`/var/www/config/ExtraLocalConfig.ini`) is deliberately not backed up; setup asks for it again.
MediaWiki only supports upgrading from up to two LTS releases back, so 1.36 can go straight to 1.43, but not to 1.47.


Backups
-------

Every hour the SQLite database and an XML dump of all pages are snapshotted, validated and copied to `MediawikiBackup` in OneDrive:
* `latest/` - the newest snapshot, overwritten every hour (OneDrive keeps the previous ones in the file's version history)
* `daily/<date>/` - one compressed snapshot per day. These are never deleted from OneDrive; prune old ones by hand when space matters.
* `images/` - the uploaded files. Files are added and updated, never deleted.
* `data/` and `dump.xml` - the layout before this change. Still used for restoring if `latest/` doesn't exist yet.

A new container restores the database and images from there when it starts with no data.

Resilience to a compromised wiki (e.g. ransomware running through PHP):
* PHP runs as `www-data`, while the OneDrive client and its token belong to a separate `onedrive` user that `www-data` can't read or write.
* The OneDrive client only uploads and never propagates deletions, so files already in OneDrive survive whatever happens in the container.
* A snapshot is published only if the database passes `PRAGMA quick_check`, it has no more than 10% fewer pages than the last published snapshot, the XML dump is complete, and at most 10 existing images changed since the previous run. Otherwise nothing is published and the run is reported as failed. The thresholds can be set with `BACKUP_MAX_PAGE_DROP_PERCENT` and `BACKUP_MAX_CHANGED_IMAGES`.
* With `HEALTHCHECK_URL` set (e.g. a free https://healthchecks.io check with a 1 hour period and some grace), each backup run pings it when everything below passes, and pings `/fail` with the reason otherwise. Healthchecks emails you on a failure *and* when pings stop, so a dead container, a broken cron or a broken backup all alert. Besides the backup itself, each run checks that:
  * the OneDrive uploader is running and the database published by the previous run reached OneDrive (according to the client's own records)
  * Apache serves the main page over HTTPS and it renders, both directly and through `https://<domain>/` (DNS and the public IP)
  * the certificate is valid for at least 14 more days (certbot renews at 30)

  These run from inside the droplet, so the public address check doesn't fully stand in for a visitor on the internet (e.g. it may bypass the Cloud Firewall).

These checks run inside the container, so an attacker who gets root in it could bypass them. Copies outside the droplet are what protect against that: OneDrive version history and recycle bin, and DigitalOcean droplet backups (enable them in the control panel).

Monitor from outside too: an uptime monitor (e.g. UptimeRobot, free) on `https://<domain>/index.php?title=Special:UserLogin` with a keyword check for the wiki name, which only succeeds when Apache, PHP and the database all work.
