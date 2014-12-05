#!/bin/bash
set -eux

PrivateKeyToPublicHttpServer="$PrivateKeyToPublicHttpServer"
PublicHttpServerOpenStackPath="$PublicHttpServerOpenStackPath"
PublicHttpServerUserAndHost="$PublicHttpServerUserAndHost"

FOLDER=$FOLDER

function ssh_dl() {
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -i $PrivateKeyToPublicHttpServer \
        $PublicHttpServerUserAndHost \
        "$@"
}

echo "Printing actual configuration"
ssh_dl cat $PublicHttpServerOpenStackPath/xenapi-in-the-cloud-appliances/.htaccess

ssh_dl "dd of=$PublicHttpServerOpenStackPath/xenapi-in-the-cloud-appliances/.htaccess" << EOF
Redirect 302 /OpenStack/xenapi-in-the-cloud-appliances/prod_ci http://2a5b493467856c19f6b9-2e6ab7b4e88777df4b0436fe9bf459ad.r57.cf5.rackcdn.com/$FOLDER/image.xva
EOF

echo "Printing new configuration"
ssh_dl cat $PublicHttpServerOpenStackPath/xenapi-in-the-cloud-appliances/.htaccess


