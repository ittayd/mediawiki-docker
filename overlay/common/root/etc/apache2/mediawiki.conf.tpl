# Set upload limit to 210MB to allow for larger file uploads
# NOTE: this limit is also enforced by php's limits, see /etc/php.ini
LimitRequestBody 220200960

# Support for SSL, redirect HTTP to HTTPS and place in SSL stuff.
<IfModule ssl_module>
  <VirtualHost *:80>
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI}
  </VirtualHost>

  <VirtualHost *:443>
    AllowEncodedSlashes NoDecode
    SSLEngine on
    ServerName ${SERVER_DOMAIN}
    SSLCertificateFile /etc/apache2/ssl.crt
    SSLCertificateKeyFile /etc/apache2/ssl.key
#    SSLCertificateChainFile /etc/apache2/ssl.bundle.crt
  </VirtualHost>
</IfModule>

<Directory /var/www/html>
  # Use of .htaccess files exposes a lot of security risk,
  # disable them and put all the necessary configuration here instead.
  AllowOverride None

  RewriteEngine On
  RewriteBase /
  RewriteRule ^index\.php$ - [L]
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule . /index.php [L]
</Directory>

<Directory /var/www/html/images>
  # Ignore .htaccess files
  AllowOverride None

  # Serve HTML as plaintext, don't execute SHTML
  AddType text/plain .html .htm .shtml .php

  # Don't run arbitrary PHP code.
  php_admin_flag engine off
</Directory>

# Protect risky directory from abuse
<Directory /var/www/html/cache/>
  Deny from all
</Directory>
<Directory /var/www/html/includes/>
  Deny from all
</Directory>
<Directory /var/www/html/languages/>
  Deny from all
</Directory>
<Directory /var/www/html/maintenance/>
  Deny from all
</Directory>
<Directory /var/www/html/maintenance/archives/>
  Deny from all
</Directory>
<Directory /var/www/html/serialized/>
  Deny from all
</Directory>
<Directory /var/www/html/tests/>
  Deny from all
</Directory>
<Directory /var/www/html/tests/qunit/>
  Allow from all
</Directory>

