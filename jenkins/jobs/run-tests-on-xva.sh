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
    cat | sed 's/^/ERROR: /'
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


function print_usage_and_die() {
    log_error << EOF
$1
Usage: $0 xenserver xva_location suppack_location
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

    log_info << EOF
Listing parameters
------------------
xenserver:        $xenserver
xva_location:     $xva_location
suppack_location: $suppack_location

EOF
    echo " - Importing xva..." | log_info
    import_xva_from_url $xenserver $xva_location
    echo " - Installing suppack..." | log_info
    install_suppack $xenserver $suppack_location
}

main $@
