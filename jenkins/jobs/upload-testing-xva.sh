#!/bin/bash
set -eux


function validate_parameters() {
    DRY_RUN=${DRY_RUN}
    CONTAINER=${CONTAINER}

    if [ -z "$CONTAINER" ]; then
        echo "CONTAINER cannot be an empty string" >&2
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


rm -rf infra
hg clone http://hg.uk.xensource.com/openstack/infrastructure.hg/ infra

cd infra/osci

./ssh.sh prod_ci echo "Connection OK"

if [ "$DRY_RUN" = "YES" ]; then
    cat > upload_script.sh << EOF
set -eux
rm -rf /tmp/img_upload
mkdir /tmp/img_upload
echo "hello" > /tmp/img_upload/image.xva
sudo -u osci -i /opt/osci/env/bin/osci-upload -c $CONTAINER -r IAD /tmp/upload image
EOF

    ./scp.sh prod_ci upload_script.sh upload_script.sh
    ./ssh.sh prod_ci bash upload_script.sh
EOF
    exit 0
fi

echo "Not implemented" >&2
exit 1
