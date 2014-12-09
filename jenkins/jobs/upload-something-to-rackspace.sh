#!/bin/bash
# This script is used to upload something to the rackspace cloud to rackspace
# files, to the IAD region, into CONTAINER. The something could be either:
# * URI_TO_RESOURCE specifying a URI to a file
# * PROD_CI_LOCAL_FOLDER specifying a folder on prod_ci machine
# The folder name within the container could be specified by the FOLDER
# parameter.

set -eux

THIS_FILE=$(readlink -f $0)
THIS_DIR=$(dirname $THIS_FILE)

. $THIS_DIR/infralib/functions.sh


function main() {
    validate_parameters
    print_out_parameters
    check_out_infra
    enter_infra
    check_connection

    cat > upload_script.sh << EOF
set -eux
rm -rf /tmp/rax_upload

function finish() {
    rm -rf /tmp/rax_upload
}
trap finish EXIT
EOF

    if [ -n "$URI_TO_RESOURCE" ]; then
        cat >> upload_script.sh << EOF
mkdir /tmp/rax_upload
pushd /tmp/rax_upload
wget -q $URI_TO_RESOURCE
popd
EOF
    else
        cat >> upload_script.sh << EOF
mv $PROD_CI_LOCAL_FOLDER /tmp/rax_upload
EOF

    fi

    cat >> upload_script.sh << EOF
sudo -u osci -i /opt/osci/env/bin/osci-upload \\
    -c $CONTAINER \\
    -r IAD /tmp/rax_upload $FOLDER
EOF

    print_out_script
    ./scp.sh prod_ci upload_script.sh upload_script.sh
    ./ssh.sh prod_ci bash upload_script.sh
}


function check_connection() {
    ./ssh.sh prod_ci echo "Connection OK"
}


function print_out_script() {
    echo "*** Printing out script ***"
    cat upload_script.sh
    echo "*** End of script ***"
}

function print_out_parameters() {
    cat << EOF
-------------------------------------------------------------------------------
Uploading an XVA to rackspace cloud from prod_ci with the following parameters

    CONTAINER=$CONTAINER
    FOLDER=$FOLDER
    PROD_CI_LOCAL_FOLDER=$PROD_CI_LOCAL_FOLDER
    URI_TO_RESOURCE=$URI_TO_RESOURCE
-------------------------------------------------------------------------------
EOF
}

function validate_parameters() {
    CONTAINER=${CONTAINER}
    PROD_CI_LOCAL_FOLDER=${PROD_CI_LOCAL_FOLDER:-}
    URI_TO_RESOURCE=${URI_TO_RESOURCE:-}
    FOLDER=${FOLDER}

    if [ -z "$CONTAINER" ]; then
        echo "CONTAINER cannot be an empty string" >&2
        exit 1
    fi

    if [ -z "$FOLDER" ]; then
        echo "FOLDER cannot be an empty string" >&2
        exit 1
    fi

    if [ -z "$PROD_CI_LOCAL_FOLDER" -a -z "$URI_TO_RESOURCE" ]; then
        echo "Specify either PROD_CI_LOCAL_FOLDER or URI_TO_RESOURCE"
        exit 1
    elif [ -n "$PROD_CI_LOCAL_FOLDER" -a -n "$URI_TO_RESOURCE" ]; then
        echo "Specify only PROD_CI_LOCAL_FOLDER or URI_TO_RESOURCE, not both"
        exit 1
    fi
}

main
