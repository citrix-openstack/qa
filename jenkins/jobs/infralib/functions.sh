function check_out_infra() {
    [ -d infra ] || hg clone http://hg.uk.xensource.com/openstack/infrastructure.hg/ infra
    pushd infra
    hg pull -u
    popd
}


function enter_infra_osci() {
    cd infra/osci
}
