#!/bin/bash

/bin/bash /etc/services.d/onedrive/run check || exit 1

/backup.sh restore

exec /init