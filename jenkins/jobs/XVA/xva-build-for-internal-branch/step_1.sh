#!/bin/bash
set -eux

./generate-citrix-job.sh "$REF_NAME" nova-network > ${BUILD_NUMBER}.sh

scp -o 'StrictHostKeyChecking no' ${BUILD_NUMBER}.sh jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/${BUILD_TAG}.sh

cat > ${BUILD_NUMBER}.properties << EOF
SETUPSCRIPT_URL=http://copper.eng.hq.xensource.com/builds/${BUILD_TAG}.sh
NOVA_REPO=git://gold.eng.hq.xensource.com/git/internal/builds/nova.git
NOVA_BRANCH=${REF_NAME}
JEOS_URL=http://copper.eng.hq.xensource.com/jeos/internal-precise.xva
PUBLISH_RESULTS=false
EOF
