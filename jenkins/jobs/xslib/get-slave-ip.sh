#!/bin/bash

set -eu

DOMID=$(xe vm-list name-label=slave --minimal)
function getip
{
    xe vm-param-get uuid=$DOMID param-name=networks 
}

while ! getip | grep -q "0/ip";
do
sleep 1
done

xe vm-param-get uuid=$DOMID param-name=networks | sed -ne 's,^.*0/ip: \([0-9.]*\).*$,\1,p'
