#!/bin/bash
set -eux

THISDIR="$(cd "$(dirname $0)" && pwd)"
. "${THISDIR}/../lib.sh"

ssh guard@silicon lock-get-single-server --reason $BUILD_URL > "${BUILD_NUMBER}.properties"
. "$(pwd)/${BUILD_NUMBER}.properties"

echo "Removing old builds"
set -f
set +e
ssh $INTERNAL_HTTP_USER_HOST rm $(internal_novaplugins_path '*')
ssh $INTERNAL_HTTP_USER_HOST rm $(internal_xva_path '*')
set -e
set +f
