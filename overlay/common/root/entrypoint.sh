#!/bin/bash

/prepare.sh 

# need to run with /bin/bash since the s6 wrapper doesn't work yet. 
/bin/bash /etc/services.d/onedrive/run check || exit 1

/backup.sh restore

exec /init