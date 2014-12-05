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
    ./ssh.sh prod_ci << EOF
rm -rf dry_upload
mkdir dry_upload
echo "hello" > dry_upload/image.xva
sudo -u osci -i /opt/osci/env/bin/osci-upload -c $CONTAINER -r IAD dry_upload image
EOF
    exit 0
fi

echo "Not implemented" >&2
exit 1
