#!/bin/bash
set -eux


function main() {
    validate_parameters
    print_out_parameters
    check_out_infra
    enter_infra
    check_connection

    cat > upload_script.sh << EOF
set -eux
rm -rf /tmp/img_upload
EOF

    if [ "$DRY_RUN" = "YES" ]; then
        cat >> upload_script.sh << EOF
mkdir /tmp/img_upload
echo "hello" > /tmp/img_upload/image.xva
EOF
    fi

    if [ "$DRY_RUN" = "NO" ]; then
        cat >> upload_script.sh << EOF
mv xva_images /tmp/img_upload
EOF
    fi

    cat >> upload_script.sh << EOF
sudo -u osci -i /opt/osci/env/bin/osci-upload \\
    -c $CONTAINER \\
    -r IAD /tmp/img_upload $FOLDER
EOF

    ./scp.sh prod_ci upload_script.sh upload_script.sh
    ./ssh.sh prod_ci bash upload_script.sh
}


function check_out_infra() {
    rm -rf infra
    hg clone http://hg.uk.xensource.com/openstack/infrastructure.hg/ infra
}


function enter_infra() {
    cd infra/osci
}


function check_connection() {
    ./ssh.sh prod_ci echo "Connection OK"
}


function print_out_parameters() {
    cat << EOF
-------------------------------------------------------------------------------
Uploading an XVA to rackspace cloud from prod_ci with the following parameters

    DRY_RUN=$DRY_RUN
    CONTAINER=$CONTAINER
    FOLDER=$FOLDER
-------------------------------------------------------------------------------
EOF
}

function validate_parameters() {
    DRY_RUN=${DRY_RUN}
    CONTAINER=${CONTAINER}
    FOLDER=${FOLDER}

    if [ -z "$CONTAINER" ]; then
        echo "CONTAINER cannot be an empty string" >&2
        exit 1
    fi

    if [ -z "$FOLDER" ]; then
        echo "FOLDER cannot be an empty string" >&2
        exit 1
    fi


    if [ "YES" = "$DRY_RUN" ]; then
        return;
    fi

    if [ "NO" = "$DRY_RUN" ]; then
        return;
    fi

    echo "DRY_RUN must be YES or NO" >&2
    exit 1
}

main


