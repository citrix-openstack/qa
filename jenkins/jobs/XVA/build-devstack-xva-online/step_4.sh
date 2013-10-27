#!/bin/bash
set -eux

if [ "$PUBLISH_RESULTS" = "false" ]; then
  echo "No publish was requested, exiting"
  exit 0
fi


. "$(pwd)/${BUILD_NUMBER}.saveenv"

echo "Mirroring build result from copper to public http server"
ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost wget http://10.219.13.54/builds/novaplugins-$TODAY.iso -O $PublicHttpServerOpenStackPath/novaplugins-$TODAY.iso
ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost wget http://10.219.13.54/builds/devstack-$TODAY.xva -O $PublicHttpServerOpenStackPath/devstack-$TODAY.xva
echo "Tidying up old builds on public http server"
ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost rm -f $PublicHttpServerOpenStackPath/novaplugins-$SIXDAYSAGO.iso || true
ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost rm -f $PublicHttpServerOpenStackPath/devstack-$SIXDAYSAGO.xva || true

echo "The published build result is now located at:"
echo "    $PublicHttpServerOpenStackLocation/novaplugins-$TODAY.iso"
echo "    $PublicHttpServerOpenStackLocation/devstack-$TODAY.xva"
