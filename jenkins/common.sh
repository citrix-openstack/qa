thisdir=$(dirname $(readlink -f "$0"))
. "$thisdir/common-xe.sh"

INSTALLED_REPOS="/etc/xensource/installed-repos"
SUPP_PACK_INSTALL_DIR="$INSTALLED_REPOS/xs:xenserver-openstack"
SUPP_PACK_UNINSTALL_SH="$SUPP_PACK_INSTALL_DIR/uninstall.sh"
SUPP_PACK_VPX_INSTALL_DIR="$INSTALLED_REPOS/xs:xenserver-openstack-vpx"
SUPP_PACK_VPX_UNINSTALL_SH="$SUPP_PACK_VPX_INSTALL_DIR/uninstall.sh"

declare -a on_exit_hooks

on_exit()
{
    for i in "${on_exit_hooks[@]}"
    do
        eval $i
    done
}

add_on_exit()
{
    local n=${#on_exit_hooks[*]}
    on_exit_hooks[$n]="$*"
    if [[ $n -eq 0 ]]
    then
        trap on_exit EXIT
    fi
}

establish_tunnel()
{
    # Note that this function takes the name of a global variable as its 4th
    # argument.  It needs to do this because we need to return the port
    # number, but we can't do it with echo because need the backgrounded
    # ssh to run in the top-level context, not a subshell.  We put the
    # port in a global variable to get around this.

    local worker="$1"       # the IP of the VPX worker
    local o_port="$2"       # the port on the VPX worker to be tunnelled
    local server="$3"       # the IP or fqdn of the XS host
    local port_ptr="$4"     # the tunnel port, leave blank to autogenerate

    if [ -z "$worker" ]
    then
      echo "Was passed the empty string instead of a worker address." >&2
      echo "This usually indicates that the worker was not found." >&2
      exit 1
   fi

    port_val=$(eval "echo \$$port_ptr")
    if [ -z "$port_val" ]
    then
       t_port=$(($RANDOM % 64511 + 1024))
       eval "$4=$t_port"
    else
       t_port=$port_val
    fi
    ssh -n -N -L "$t_port:$worker:$o_port" "root@$server" &
    tunnel=$!
    add_on_exit "kill $tunnel || true"
    sleep 1 # Let the tunnel come up
}

remote_execute()
{
    local server="$1"
    local lscript="$2"
    shift 2
    local rscript=$(basename "$lscript")
    tmpdir=$(ssh "$server" mktemp -d)
    add_on_exit "ssh '$server' rm -rf '$tmpdir'"

    scp "$lscript" "$server:$tmpdir"
    scp "$thisdir/common.sh" "$server:$tmpdir"
    scp "$thisdir/common-xe.sh" "$server:$tmpdir"
    scp "$thisdir/common-vpx.sh" "$server:$tmpdir"
    ssh "$server" "chmod u+x $tmpdir/$rscript"
    ssh "$server" "$tmpdir/$rscript" "$@"
}

get_site()
{
    if [ "${autosite_server-}" ]
    then
        domain=$(ssh "root@$autosite_server" hostname -d)
        case "$domain" in
        "eng.hq.xensource.com")
            echo "sc"
            ;;
        "uk.xensource.com")
            echo "cam"
            ;;
        "cam.eu.citrix.com" | "eng.citrite.net")
            echo "cmb"
            ;;
        *)
            echo "Cannot determine site.  Bailing!" >&2
            exit 1
            ;;
        esac
    elif [ "${SITE-}" ]
    then
        echo "$SITE"
    else
        echo "Cannot determine site.  Bailing!" >&2
        exit 1
    fi
}

get_xb_build_number_from_builddir()
{
    local bn_path="$1"
    (if [ "$BUILD_RESULT_DIR" ]
     then
         cat "$BUILD_RESULT_DIR/$bn_path"
     else
         wget -q "$BUILD_RESULT_URL/$bn_path" -O -
     fi) | sed -e 's/[^0-9]//g'
}

get_xb_build_number()
{
    # Note that openstack/trunk is hardcoded here -- this doesn't make sense
    # for git builds, and I don't know whether that's OK or not.
    "$thisdir/build/get_xb_build_number" ||
        get_xb_build_number_from_builddir \
            "openstack/trunk/os-vpx-latest/os-vpx/BUILD_NUMBER"
}

get_vpx_product_version()
{
    local build_url="$1"
    local filename="$2"
	wget -q "$build_url/$filename" -O - | 
				sed -n "s/PRODUCT_VERSION=// p" | xargs echo
}

clean_jenkins()
{
    if [ "${JENKINS_CLEANED-}" ]
    then
        return
    fi
    echo "Cleaning up jenkins environment"
    rm -f $thisdir/screenshot*.png
    rm -f /tmp/test_key*.pem
    export JENKINS_CLEANED=true
}

enter_jenkins_test()
{
    echo "Test environment begins:"
    env
    echo "Test environment ends."

    site=$(get_site)
    . "$thisdir/sites/$site"

    if [ "${PrivateBuildURL-}" ]
    then
        xb_build_number="Private"
        build_url="$PrivateBuildURL"
        product_version="x.x.x"
    else
        xb_build_number=$(get_xb_build_number)
        # The build number has the # in front for os-vpx-build-manifest.
        # Strip it off.
        xb_build_number="${xb_build_number/\#/}"
        if [ $xb_build_number -ge 2000 ]
        then
            # Github builds -- the build number is >2000.  Take the
            # build from the special "openstack/all" branch.
            build_url="$BUILD_RESULT_URL/openstack/all/$xb_build_number/os-vpx"
        else
            # XenBuilder builds.  Assume openstack/trunk for the branch.
            build_url="$BUILD_RESULT_URL/openstack/trunk/$xb_build_number/os-vpx"
        fi
        product_version=$(get_vpx_product_version "$build_url" globals)
    fi

    "$thisdir/build/set_test_description" "$JENKINS_URL" "$JOB_NAME" \
        "$BUILD_NUMBER" "$xb_build_number"

    echo "Build ID: $BUILD_ID."
    echo "Jenkins site: ${SITE-Unknown}."
    echo "Test server site: $site."
    echo "Build number: $xb_build_number."
    echo -n "Repository: "
    (cd "$thisdir" && hg paths)
    echo -n "Changeset: "
    (cd "$thisdir" && hg id)

    clean_jenkins
}

start_selenium_rc()
{
    local port="$1"
    DISPLAY=:5 java -Djava.awt.headless=false -jar /opt/selenium/selenium-server-standalone.jar -browserSessionReuse -port $port &
    selenium_rc=$!
    add_on_exit "kill $selenium_rc || true"
    sleep 20 # wait for selenium to start before returning
}

wait_for_build_to_finish()
{
  local url="$1"
  local filename="$2"
  local new_filename="$3"
  retries=0
  while ! wget -q "$url/$filename" -O "$new_filename"
  do
    echo "Did not find $url/$filename." >&2
    if [ "$retries" = "120" ]
    then
      echo "Aborting this test run altogether." >&2
      exit 1
    else
      echo "Sleeping to allow this site's build to catch up." >&2
      sleep 60
      retries=$(($retries + 1))
    fi
  done
}

fetch_xenserver_bits()
{
  local url="$1"
  local filename="xenserver-openstack-supp-pack.iso"

  # If other artifacts are ready, it does not 
  # mean that so is the supp-pack.
  wait_for_build_to_finish "$url" "$filename" "$filename"
  wget -q "$url/$filename"
}

fetch_vpx_scripts()
{
  wget -q "$1/install-os-vpx.sh"
  wget -q "$1/uninstall-os-vpx.sh"
}

fetch_vpx_pieces()
{
  local url="$1"
  local devel="$2"
  local filename

  if $devel
  then
    filename="os-vpx-devel.xva"
  else
    filename="os-vpx.xva"
  fi
  
  wait_for_build_to_finish "$url" "$filename" "os-vpx.xva"
  fetch_vpx_scripts "$url"
  fetch_xenserver_bits "$url"
}

clean_host()
{
    # Remove os-vpx
    sh -x uninstall-os-vpx.sh --remove-data
    IFS=,
    networks=$(xe_min network-list other-config:vpx-test=true)
    for n in $networks
    do
        destroy_network "$n"
    done
    unset IFS
    
    # Remove Nova instances, if any
    uuids=$(xe_min vm-list is-control-domain=false)
    IFS=,
    for uuid in $uuids
    do
        if xe_min vm-list params=name-label uuid=$uuid | grep instance
        then
            xe vm-param-set other-config:nova=true uuid=$uuid
            uninstall "$uuid"
        fi
    done
    unset IFS
    # Delete dangling Glance/Nova VM VDIs, if any
    # Sometimes Glance VDIs may lurke around the system if we have failed
    # tests. Make sure we don't leak.
    uuids=$(xe_min vdi-list)
    IFS=,
    for uuid in $uuids
    do
        label=$(xe_min vdi-list params=name-label uuid=$uuid)
        if [ "$(echo "$label" | grep instance)" -o \
                                          "$(echo "$label" | grep Glance)" ]
        then
            xe vdi-param-set other-config:nova=true uuid=$uuid
        fi
    done
    unset IFS
    uuids=$(xe_min vdi-list other-config:nova=true)
    destroy_vdis "$uuids"
    
    # Remove external ramdisk and kernel files
    rm -rf /boot/guest

    if [ -x "$SUPP_PACK_VPX_UNINSTALL_SH" ]
    then
      yes | sh -x "$SUPP_PACK_VPX_UNINSTALL_SH"
    fi

    if [ -x "$SUPP_PACK_UNINSTALL_SH" ]
    then
      yes | sh -x "$SUPP_PACK_UNINSTALL_SH"
    fi
    
    # Remove xapi blobs so that we have a clean set of performance metrics
    # before we run the test
    rm -rf /var/xapi/blobs/*
    
    # Remove known_hosts so that we don't get annoying ssh warnings when
    # we try to ssh into a VPX (especially the master, as it is always
    # 169.254.0.2) across different test runs
    rm -f /root/.ssh/known_hosts
    
    # Sometimes temp dirs created by remote_execute 
    # are not cleaned up. So make sure we don't leak 
    find /tmp -maxdepth 1 \( -name tmp.\* \) -a -mtime +1 -exec rm -R \{\} \;
    
    # Sometimes VPX system disks do not get marked with
    # other-config:os-vpx=true. So make sure we don't leak
    uuids=$(xe_min vdi-list \
                   name-label="XenServer OpenStack VPX system disk" \
                   other-config)
    destroy_vdis "$uuids"
    
    # Sometimes VPX disks, like swift or nova-volume disks, do not get
    # cleaned during the VM uninstallation process. So make sure we 
    # don't leak
    uuids=$(xe_min vdi-list other-config:os-vpx-extra=true)
    destroy_vdis "$uuids"
    
    # Remove old os-vpx-bugtool tarballs
    rm -rf /var/opt/xen/bug-report/os-vpx-bugtool-*
}

#
# Put xapi (i.e. dom0) on the management network.
#
# If the management network is a host-private network then we have to use
# an evil hack: we ignore the given management network, but create a VLAN on
# $dev, tag 4094, and use that instead.
#
# $dev tag 4094 has been chosen to avoid collisions within the various test
# environments that we have.
#
# We have to do this because xapi's PIF / network model does not allow you to
# put an IP address on a host-private network, even though it's technically
# possible to do so.
#
# Returns the correct management network to use, which will be the given one
# in the multi-host case, and the VLAN in the single-host case.
#
introduce_xapi_to_management_network()
{
    local dev="$1"
    local m_net="$2"
    local addr="$3"
    local mask="$4"

    local m_net_uuid
    local pif_uuid
    if [ "$m_net" = '' ]
    then
      pif_uuid=''
    else
      m_net_uuid=$(find_network "$m_net")
      pif_uuid=$(xe_min pif-list network-uuid=$m_net_uuid)
    fi
    if [ "$pif_uuid" = '' ]
    then
      if [ "$m_net" != '' ]
      then
        echo "Warning: ignoring the specified management network ($m_net) " \
             "and using VLAN 4094 on ($dev) instead." >&2
      fi
      m_net=$(create_test_network)
      m_net_uuid=$(find_network "$m_net")
      local ethX_pif=$(xe_min pif-list device="$dev" VLAN=-1)
      pif_uuid=$(xe_min vlan-create pif-uuid=$ethX_pif \
                                    network-uuid=$m_net_uuid vlan=4094)
    fi 
    # we go with static settings otherwise /etc/resolv.conf 
    # on the XS host gets wiped out.
    xe_min pif-reconfigure-ip uuid=$pif_uuid IP=$addr netmask=$mask \
      mode=static >/dev/null
    echo "$m_net"
}

create_test_network()
{
    uuid=$(xe network-create name-label="Management")
    xe network-param-set uuid=$uuid other-config:vpx-test=true
    xe_min network-list uuid=$uuid params=bridge
}

install_xenserver_openstack_supp_pack()
{
  # Note that we don't want to proceed if we get any questions.  These
  # would be "dependency check failed, do you want to proceed?" or similar.
  yes n | xe-install-supplemental-pack xenserver-openstack-supp-pack.iso
}

#
# install_vpx mode wait m_net p_net kargs flavour disk memory balloning
#
# mode     [-cLabel|-i]    Clone a template or install from scratch.
# wait     [1|]            Wait for IP details or don't.
# m_net    e.g. xenbr0     Management network.
# p_net    e.g. xenbr1     Public network.
# kargs                    Kernel command line arguments.
# flavour  [master|slave]  Used to identify the VPX later.
# disk                     Size in MiB.
# memory                   RAM in MiB.
# ballooning [-b]          Enable memory ballooning for the VPX.
#
install_vpx()
{
    if [ "$2" ]
    then
        wait="-w"
    else
        wait=
    fi
    sh -x install-os-vpx.sh "$1" $wait -m "$3" -p "$4" -k "$5" -r "$8" \
                            -d "$7" $9 -o "vpx-test-$6=true vpx-test=true"
}

install()
{
    local server="$1"
    local device="$2"
    local num_masters="$3"
    local kern_args="$4"
    local master_ram="$5"
    local num_slaves="$6"
    local slave_ram="$7"
    local wait_flag="$8"
    local management_ip="$9"
    local management_net="${10-}"
    local public_net="${11-}"
    [ "$management_net" == "" ] && management_net=$m_net
    [ "$public_net" == "" ] && public_net=$p_net
    (remote_execute "root@$server" "$thisdir/geppetto/install_vpxs_multihost.sh" \
        "'$build_url'" "$device" "'$management_net'" "'$public_net'" "'$devel'" \
        "'$num_masters'" "'$kern_args'" "'$master_ram'" \
        "'$num_slaves'" "'$slave_ram'" "'$wait_flag'" "'$management_ip'")&
    pids="$pids $!"
}

wait_for()
{
    failures=0
    for pid in $1
    do
        wait "$pid" || let failures++
    done
    if [ "$failures" != "0" ]
    then
        echo "$failures installations failed." >&2
        exit 1
    fi
}

parse_result()
{
    local code="$1"
    [ "$code" -eq 0 ] && result_img="ok.png" || result_img="ko.png"
    cp "$thisdir/utils/imgs/$result_img" "$thisdir/screenshot_$result_img"
    echo $code
}
