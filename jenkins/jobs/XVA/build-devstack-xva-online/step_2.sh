#!/bin/bash
set -eux

. "$(pwd)/${BUILD_NUMBER}.properties"

jenkins/jobs/xva-build.sh $HOST $XenServerPassword "$SETUPSCRIPT_URL" "$NOVA_REPO" "$NOVA_BRANCH" "$JEOS_URL"

SLAVE_IP="$(cat jenkins/jobs/xslib/get-slave-ip.sh | jenkins/jobs/remote/bash.sh $HOST)"

echo "Copying build result to internal copper"
TODAY=$(date +"%m_%d_%Y")
scp -B -3 -o 'StrictHostKeyChecking no' ubuntu@$SLAVE_IP:~/suppack/novaplugins.iso \
    jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/novaplugins-$TODAY.iso
ssh jenkinsoutput@copper.eng.hq.xensource.com chmod 755 /usr/share/nginx/www/builds/novaplugins-$TODAY.iso

scp -B -3 -o 'StrictHostKeyChecking no' ubuntu@$SLAVE_IP:~/devstack.xva \
    jenkinsoutput@copper.eng.hq.xensource.com:/usr/share/nginx/www/builds/devstack-$TODAY.xva
ssh jenkinsoutput@copper.eng.hq.xensource.com chmod 755 /usr/share/nginx/www/builds/devstack-$TODAY.xva

echo "Tidying up old builds on copper"
SIXDAYSAGO=$(date --date="$(date)-5days" +"%m_%d_%Y")
ssh jenkinsoutput@copper.eng.hq.xensource.com rm -f /usr/share/nginx/www/builds/novaplugins-$SIXDAYSAGO.iso || true
ssh jenkinsoutput@copper.eng.hq.xensource.com rm -f /usr/share/nginx/www/builds/devstack-$SIXDAYSAGO.xva || true

echo "The internal build result is now located at:"
echo "    http://copper.eng.hq.xensource.com/builds/novaplugins-$TODAY.iso"
echo "    http://copper.eng.hq.xensource.com/builds/devstack-$TODAY.xva"

# Save internal build's details to a file
cat > ${BUILD_NUMBER}.internal.properties << EOF
DEVSTACK_XVA_URL=http://copper.eng.hq.xensource.com/builds/devstack-$TODAY.xva
DEVSTACK_SUPPACK_URL=http://copper.eng.hq.xensource.com/builds/novaplugins-$TODAY.iso
EOF

# Save environment variables
cat > ${BUILD_NUMBER}.saveenv << ENV_VARS
TODAY=$TODAY
SIXDAYSAGO=$SIXDAYSAGO
ENV_VARS
