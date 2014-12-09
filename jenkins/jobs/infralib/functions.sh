function check_out_infra() {
    rm -rf infra
    hg clone http://hg.uk.xensource.com/openstack/infrastructure.hg/ infra
}


function enter_infra() {
    cd infra/osci
}
