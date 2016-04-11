#!/bin/bash
set -eux

if [ "$1" = "daily" ]; then
    THISDIR="$(cd "$(dirname $0)" && pwd)"
    . "$THISDIR/lib.sh"

    [ -n "$REF_NAME" ]
    [ -n "$DEVSTACK_INSTALLER_SCRIPT_URL" ]

    # This is a daily build
    TODAY=$(date +"%Y_%m_%d")
    XVA_NAME="${TODAY}"
    NOVAPLUGINS_URL="$PublicHttpServerOpenStackLocation/$(novaplugins_name $XVA_NAME)"

    # Let's see if a build is needed...
    if curl -sI "$NOVAPLUGINS_URL" | grep -q 404; then
        echo "No build found for today"
    else
        echo "Build found for today"
        exit 1
    fi
else
    [ "$1" = "named" ]
fi
EDITED_SCRIPT="$2"
PARAMETER_FILE="$3"


# Edit the installer script, and replace the repos with the public ones.
#wget -qO - "$DEVSTACK_INSTALLER_SCRIPT_URL" |
#    ./change-repos-of-generated-jobs-to-public.sh |
#    ./remove-ubunutu-install-settings.sh > $EDITED_SCRIPT

wget -qO - "$DEVSTACK_INSTALLER_SCRIPT_URL" |
    ./change-repos-of-generated-jobs-to-public.sh > $EDITED_SCRIPT

# Copy the installer script to a web server
scp ${BUILD_NUMBER}.sh "devstack_script_producer@unsteve.eng.hq.xensource.com:/devstack-scripts/${BUILD_TAG}.sh"

cat > $PARAMETER_FILE << EOF
SETUPSCRIPT_URL=http://unsteve.eng.hq.xensource.com/build-results/devstack-scripts/${BUILD_TAG}.sh
NOVA_REPO=https://github.com/citrix-openstack-build/nova.git
NOVA_BRANCH=${REF_NAME}
JEOS_URL=http://copper.eng.hq.xensource.com/jeos/external-trusty.xva
PUBLISH_RESULTS=true
XVA_NAME=${XVA_NAME}
XVA_INTERNAL_NAME=${BUILD_TAG}
EOF
