#!/bin/bash

set -eux

if [ -z "$REF_NAME" ]; then
  echo "No ref specified"
  exit 1
fi

[ "$PUBLISH_REF_NAME" = "ctx-nova-network-smoke-latest" ]

TODAY=$(date +"%m_%d_%Y")
TODAYS_URL="http://downloads.vmd.citrix.com/OpenStack/novaplugins-$TODAY.iso"

# Let's see if a build is needed...
if curl -sI "$TODAYS_URL" | grep -q 404; then
  echo "No build found for today"
else
  echo "Build found for today"
  exit 1
fi

./generate-citrix-job.sh "$REF_NAME" nova-network |
  ./change-repos-of-generated-jobs-to-public.sh |
  ./remove-ubunutu-install-settings.sh > ${BUILD_NUMBER}.sh

scp -o 'StrictHostKeyChecking no' ${BUILD_NUMBER}.sh jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/${BUILD_TAG}.sh

cat > ${BUILD_NUMBER}.properties << EOF
SETUPSCRIPT_URL=http://copper.eng.hq.xensource.com/builds/${BUILD_TAG}.sh
NOVA_REPO=https://github.com/citrix-openstack-build/nova.git
NOVA_BRANCH=${REF_NAME}
JEOS_URL=http://copper.eng.hq.xensource.com/jeos/external-precise.xva
PUBLISH_RESULTS=true
EOF
