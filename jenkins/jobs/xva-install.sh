#!/bin/bash

set -eu

XSLIB=$(cd $(dirname $(readlink -f "$0")) && cd xslib && pwd)
REMOTELIB=$(cd $(dirname $(readlink -f "$0")) && cd remote && pwd)


function log_info() {
    echo -ne "\e[0;32m"
    cat
    echo -ne "\e[0m"
}


function log_error() {
    echo -ne "\e[0;31m"
    cat
    echo -ne "\e[0m"
}

function import_xva_from_url() {
    local xenserver
    local xva_location

    xenserver="$1"
    shift
    xva_location="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
rm -f devstack.xva
wget -qO devstack.xva $xva_location
xe vm-import filename=devstack.xva > /dev/null
rm -f devstack.xva
EOF
}

function no_devstack_vm() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
[ -z "\$(xe vm-list name-label=DevStackOSDomU --minimal)" ]
EOF
}

function install_suppack() {
    local xenserver
    local suppack_location

    xenserver="$1"
    shift
    suppack_location="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
rm -f nova_suppack.iso
wget -qO nova_suppack.iso $suppack_location
echo "Y" | xe-install-supplemental-pack nova_suppack.iso > /dev/null
rm -f nova_suppack.iso
EOF
}

function show_devstack_network_config() {
    local xenserver

    xenserver="$1"
    shift

    $REMOTELIB/bash.sh root@$xenserver << EOF
xe vif-list vm-name-label=DevStackOSDomU params=device,network-name-label
xe network-list params=bridge,name-label
EOF
}


function print_usage_and_die() {
    log_error << EOF
usage: $0 xenserver xva_location suppack_location

Install a devstack xva together with the nova plugins.

$1
EOF
    exit 1
}


function main() {
    local xenserver
    local xva_location
    local suppack_location

    set +u
    xenserver="$1"
    shift || print_usage_and_die "xenserver not specified"
    xva_location="$1"
    shift || print_usage_and_die "xva_location not specified"
    suppack_location="$1"
    shift || print_usage_and_die "suppack_location not specified"
    set -u

    cat << EOF
Listing parameters
------------------
xenserver:        $xenserver
xva_location:     $xva_location
suppack_location: $suppack_location

EOF
    echo " - Checking for existing devstack machine..."
    if no_devstack_vm $xenserver; then
        echo "   No vm found" | log_info
    else
        log_error << EOF
   A VM with the name DevStackOSDomU was found. This function is not yet
   implemented. Please remove the VM manually, and re-run this script.
EOF
        exit 1
    fi
    echo " - Importing xva..."
    import_xva_from_url $xenserver $xva_location
    echo "   Done" | log_info

    echo " - Installing suppack..."
    install_suppack $xenserver $suppack_location
    echo "   Done" | log_info
    echo " - Displaying network configuration"
    show_devstack_network_config $xenserver
    echo "   Done" | log_info
}

main $@
