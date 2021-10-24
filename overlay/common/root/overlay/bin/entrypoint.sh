#!/bin/bash

if [ ! -e /etc/setup-done ]; then 
    for f in /etc/setup.d/*; do
        echo "$f: "
        . $f setup || { echo "Abnormal exit, aborting setup" > /dev/stderr; exit 1; }
    done
    touch /etc/setup-done
fi

exec ${INIT_CMD:-/init} ${INIT_CMD_ARGS}