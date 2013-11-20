#!/bin/bash
set -eux

THISDIR="$(cd "$(dirname $0)" && pwd)"
. "${THISDIR}/../lib.sh"

if [ "$PUBLISH_RESULTS" = "false" ]; then
  echo "No publish was requested, exiting"
  exit 0
fi

echo "Mirroring build result from copper to public http server"
ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost \
    wget "http://10.219.13.54/builds/$(novaplugins_name $XVA_INTERNAL_NAME)" \
    -O "$PublicHttpServerOpenStackPath/$(novaplugins_name $XVA_NAME)"

ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost \
    wget "http://10.219.13.54/builds/$(xva_name $XVA_INTERNAL_NAME)" \
    -O "$PublicHttpServerOpenStackPath/$(xva_name $XVA_NAME)"

echo "Remove internal builds"
ssh $INTERNAL_HTTP_USER_HOST rm -f \
    $(internal_novaplugins_path $XVA_INTERNAL_NAME) \
    $(internal_xva_path $XVA_INTERNAL_NAME)

echo "The published build result is now located at:"
echo "    $PublicHttpServerOpenStackLocation/$(novaplugins_name $XVA_NAME)"
echo "    $PublicHttpServerOpenStackLocation/$(xva_name $XVA_NAME)"
