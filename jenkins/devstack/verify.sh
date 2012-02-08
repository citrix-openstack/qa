#!/bin/bash
set -eux

sleep 150

let i=1
while [ $i -lt 60 ]
do
    ((i++))
    verif=$(cat /opt/stack/run.sh.log | grep -o --only-matching "stack.sh completed in [0-9]* seconds" || true)
    if [ -z "$verif" ]
    then
        sleep 30
    else
        echo "verify done with success"
        exit 0
    fi
done
echo "verify failed"
exit 1
