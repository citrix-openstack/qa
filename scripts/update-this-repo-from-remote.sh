#!/bin/bash

set -u

REMOTE_SERVER=${1:-"bronze.eng.hq.xensource.com"}

./remote-backup-config.sh $REMOTE_SERVER
./update-config-from-temp.sh
