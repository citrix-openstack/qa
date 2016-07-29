#!/bin/bash
set -eux

ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost \
    "find $PublicHttpServerOpenStackPath/ -name 'devstack-????_??_??.xva' | \
    sort -r | sed '1,6d' | xargs rm -vf" || true

ssh -i $PrivateKeyToPublicHttpServer $PublicHttpServerUserAndHost \
    "find $PublicHttpServerOpenStackPath/ -name 'novaplugins-????_??_??.iso' | \
    sort -r | sed '1,6d' | xargs rm -vf" || true

NFSSERVER="10.62.132.4:/openstack"
NFSLOCAL=$(mktemp -d)
sudo mount $NFSSERVER $NFSLOCAL
find $NFSLOCAL/ -name 'devstack-????_??_??.xva' | \
    sort -r | sed '1,6d' | xargs sudo rm -vf || true
find $NFSLOCAL/ -name 'novaplugins-????_??_??.iso' | \
    sort -r | sed '1,6d' | xargs sudo rm -vf || true
sudo umount $NFSLOCAL
