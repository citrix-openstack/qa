#!/bin/bash
set -eux

ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost \
    "find $PublicHttpServerOpenStackPath/ -name 'devstack-??_??_????.xva' | \
    sort -r | sed '1,6d' | xargs rm -vf" || true

ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost \
    "find $PublicHttpServerOpenStackPath/ -name 'novaplugins-??_??_????.iso' | \
    sort -r | sed '1,6d' | xargs rm -vf" || true
