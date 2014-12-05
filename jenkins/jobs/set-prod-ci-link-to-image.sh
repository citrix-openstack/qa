#!/bin/bash
set -eux

PrivateKeyToPublicHttpServer="$PrivateKeyToPublicHttpServer"
PublicHttpServerOpenStackPath="$PublicHttpServerOpenStackPath"
PublicHttpServerUserAndHost="$PublicHttpServerUserAndHost"

echo "Printing actual configuration"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    -i $PrivateKeyToPublicHttpServer \
    $PublicHttpServerUserAndHost \
    cat $PublicHttpServerOpenStackPath/xenapi-in-the-cloud-appliances/.htaccess
