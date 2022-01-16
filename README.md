Do not edit the `Dockerfile`s directly. Changes should be made in the `Dockerfile-*.template` files and applied by running `update.sh`.

`bash.exe update.sh; docker build -t ittayd/mediawiki:latest -f .\1.36\apache\Dockerfile .`
`docker scan ittayd/mediawiki:latest`
`docker image push ittayd/mediawiki:latest`


After building the image, run it with -it, it needs to:
* ask for username & password to send emails through google
* get a onedrive token interactively. 
* create certs
** LE has rate limiting, so if trying running an image multiple times, use SELF_SIGNED_CERT=1 in the environment to avoid being blocked.
*** in that case /etc/letsencrypt and /etc/apache2/mediawiki.conf from the old container will work. They can be copied over while onedrive waits for the token

Also, port forward, if needed, to port 80. 

Can pass environment varialbes:
`docker run -e SMTP_USER=<gmail user> -e SMTP_PASS=<password> -e SERVER_DOMAIN=<domain> --log-opt max-size=4m --log-opt max-file=3 -it -p 80:80 -p 443:443 --name mediawiki ittayd/mediawiki:latest`
* onedrive takes some time to finish syncing. wait for `DONE`

Can do `docker exec -it mediawiki bash` to enter the container. 
* Check whether the DB file is copied to /var/www/data before doing the browser setup

The SQLite database is copied every night at 2:00 to a folder under /home/www-data/OneDrive and synced to onedrive. Images are copied using symlinks.

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

`docker cp wiki.png mediawiki:/var/www/html/resources/assets/wiki.png`

