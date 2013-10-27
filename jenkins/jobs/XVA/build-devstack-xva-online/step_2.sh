#!/bin/bash
set -eux

THISDIR="$(cd "$(dirname $0)" && pwd)"
. "${THISDIR}/../lib.sh"

. "$(pwd)/${BUILD_NUMBER}.properties"

jenkins/jobs/xva-build.sh "$HOST" "$XenServerPassword" "$SETUPSCRIPT_URL" "$NOVA_REPO" "$NOVA_BRANCH" "$JEOS_URL"

SLAVE_IP="$(cat jenkins/jobs/xslib/get-slave-ip.sh | jenkins/jobs/remote/bash.sh $HOST)"

INTERNAL_NOVAPLUGINS_PATH="$(internal_novaplugins_path $XVA_INTERNAL_NAME)"
scp -B -3 -o 'StrictHostKeyChecking no' \
    ubuntu@$SLAVE_IP:~/suppack/novaplugins.iso \
    $INTERNAL_HTTP_USER_HOST:$INTERNAL_NOVAPLUGINS_PATH
ssh $INTERNAL_HTTP_USER_HOST chmod 755 $INTERNAL_NOVAPLUGINS_PATH

INTERNAL_XVA_PATH="$(internal_xva_path $XVA_INTERNAL_NAME)"
scp -B -3 -o 'StrictHostKeyChecking no' ubuntu@$SLAVE_IP:~/devstack.xva \
    $INTERNAL_HTTP_USER_HOST:$INTERNAL_XVA_PATH
ssh $INTERNAL_HTTP_USER_HOST chmod 755 $INTERNAL_XVA_PATH

# Save internal build's details to a file so it could be verified
cat > ${BUILD_NUMBER}.internal.properties << EOF
DEVSTACK_XVA_URL=$(internal_xva_url $XVA_INTERNAL_NAME)
DEVSTACK_SUPPACK_URL=$(internal_novaplugins_url $XVA_INTERNAL_NAME)
EOF
