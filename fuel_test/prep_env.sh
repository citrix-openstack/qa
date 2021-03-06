#!/bin/bash

set -eu

. localrc

[ $DEBUG == "on" ] && set -x

function run_in_domzero {
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$XS_HOST "$@"
}

function run_in_fm {
    ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$FM_IP "$@"
}

function create_networks {
	local xs_host="$1"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	[ -z $(xe network-list name-label="'$2'" --minimal) ] && xe network-create name-label="'$2'"
	[ -z $(xe network-list name-label="'$3'" --minimal) ] && xe network-create name-label="'$3'"
	[ -z $(xe network-list name-label="'$4'" --minimal) ] && xe network-create name-label="'$4'"
	echo "Network created"
	'
}

function recreate_gateway {
	local xs_host="$1"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	bridge=$(xe network-list name-label="'$2'" params=bridge minimal=true)
	recreate_gateway_sh="/etc/udev/scripts/recreate-gateway.sh"
	cat > $recreate_gateway_sh << RECREATE_GATEWAY
#!/bin/bash
/bin/sleep 10
if /sbin/ip link show $bridge > /dev/null 2>&1; then
  if !(/sbin/iptables -L FORWARD | /bin/head -n 3 | /bin/egrep -q "ACCEPT +udp +-- +anywhere +anywhere"); then
    /sbin/iptables -I FORWARD 1 -p udp -j ACCEPT
  fi
  if !(/sbin/ip addr show $bridge | /bin/grep -q 172.16.1.1); then
    /sbin/ip addr add dev $bridge 172.16.1.1
  fi
  if !(/sbin/route -n | /bin/grep -q 172.16.1.0); then
    /sbin/route add -net 172.16.1.0 netmask 255.255.255.0 dev $bridge
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 192.168.111.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -d 192.168.111.0/24 -j RETURN
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 10.0.7.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -d 10.0.7.0/24 -j RETURN
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 10.1.7.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -d 10.1.7.0/24 -j RETURN
  fi
  if !(/sbin/iptables -t nat -S | /bin/grep -q 172.16.1.0/24); then
    /sbin/iptables -t nat -A POSTROUTING -s 172.16.1.0/24 ! -d 172.16.1.0/24 -j MASQUERADE
  fi
fi
RECREATE_GATEWAY

	chmod +x $recreate_gateway_sh
	# To skip the reboot, here explicitly run recreate-gateway.sh to activate for the first time
	$recreate_gateway_sh
	echo "SUBSYSTEM==net ACTION==add KERNEL==xapi* RUN+=$recreate_gateway_sh" > /etc/udev/rules.d/90-gateway.rules
	sed -i -e "s/net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/" /etc/sysctl.conf
	sysctl net.ipv4.ip_forward=1
	'
}

function restore_fm {
    # Restore fuel master
    local __restored_from="$1"
    local fm_name="$2"
    local fm_snapshot="$3"
    local fm_mnt="$4"
    local fm_xva="$5"
    snapshot_uuid=$(run_in_domzero '
        set -eux
        vm_uuid=$(xe vm-list name-label="'$fm_name'" --minimal)
        snapshot_uuid=$(xe snapshot-list name-label="'$fm_snapshot'" snapshot-of="$vm_uuid" --minimal)
        if [ -n "$snapshot_uuid" ]; then
            echo $snapshot_uuid
        fi
        ')
    if [ -n "$snapshot_uuid" ]; then
        run_in_domzero '
            set -eux
            xe snapshot-revert snapshot-uuid="'$snapshot_uuid'"
            xe vm-start vm="'$fm_name'"
            '
        eval $__restored_from="SNAPSHOT"
    else
        run_in_domzero '
            set -eux
            MNT_POINT=/mnt
            # just in case the mount point mounted already.
            is_mount=YES
            mount | grep -w $MNT_POINT || is_mount=NO
            if [ "$is_mount" != "NO" ]; then
                umount $MNT_POINT
                sleep 5
            fi
            mount "'$fm_mnt'" $MNT_POINT
            xe vm-import filename="$MNT_POINT/'$fm_xva'" preserve=true
            umount $MNT_POINT
            vm_uuid=$(xe vm-list name-label="'$fm_name'" --minimal)
            vif=$(xe vif-list vm-uuid=$vm_uuid device=1 --minimal)
            net=$(xe vif-list vm-uuid=$vm_uuid device=1 params=network-uuid --minimal)
            xe vif-destroy uuid=$vif
            mac=$(echo 00:60:2f$(od -txC -An -N3 /dev/random|tr \  :))
            xe vif-create vm-uuid="$vm_uuid" device=1 network-uuid="$net" mac=$mac
            xe vm-start vm="'$fm_name'"
            '
        eval $__restored_from="XVA"
    fi
}

function create_snapshot {
    local vm_name="$1"
    local snapshot_name="$2"
    run_in_domzero xe vm-snapshot vm=$vm_name new-name-label=$snapshot_name
}

function fresh_fm {
    NEED_BOOTSTRAP=no

    # check DNS: Use dom0's DNS as FM's upstream DNS
    dom0_dns_list=$(run_in_domzero grep nameserver /etc/resolv.conf | awk '{print $2}')
    new_fm_dns=""
    for dns in $dom0_dns_list
    do
        if [ -n "$new_fm_dns" ]; then
            new_fm_dns="$new_fm_dns,$dns"
        else
            new_fm_dns=$dns
        fi
    done
    new_fm_dns="\"$new_fm_dns\""
    fm_dns=$(run_in_fm grep DNS_UPSTREAM /etc/fuel/astute.yaml | cut -d':' -f2)
    if [ "$new_fm_dns" != "${fm_dns//[[:space:]]}" ]; then
        run_in_fm '
            set -eux
            # update DNS
            ASTUTE_CFG=/etc/fuel/astute.yaml
            cp -p $ASTUTE_CFG ${ASTUTE_CFG}.old
            sed -i "s/\"DNS_UPSTREAM\":.*$/\"DNS_UPSTREAM\": '$new_fm_dns'/g" $ASTUTE_CFG
            '
        echo "Updated FM's upstream DNS"
        NEED_BOOTSTRAP=yes
    fi

    if [ "$NEED_BOOTSTRAP" = "yes" ]; then
        echo "$(date) - Start bootstrap admin node..."
        run_in_fm '
            BOOTSTRAP_CFG=/etc/fuel/bootstrap_admin_node.conf
            cp -p $BOOTSTRAP_CFG ${BOOTSTRAP_CFG}.backup
            # not show fuel menu so that accept the existing default settings.
            echo "showmenu=no">> $BOOTSTRAP_CFG
            # bootstrap admin node to ensure the change to take effective.
            /usr/sbin/bootstrap_admin_node.sh
            mv ${BOOTSTRAP_CFG}.backup $BOOTSTRAP_CFG

            # Force allowing SSH from eth1; 
            iptables -A INPUT -i eth1 -p tcp --dport 22 -j ACCEPT
            /usr/libexec/iptables/iptables.init save
            sync
            '
        echo "$(date) - Done bootstrap admin node."
    fi
}

function ensure_fm {
	local fm_name="$1"
	local fm_snapshot="$2"
	local fm_mnt="$3"
	local fm_xva="$4"
    echo "Restoring Fuel Master..."
    restored_from=""
    restore_fm "restored_from" "$fm_name" "$fm_snapshot" "$fm_mnt" "$fm_xva"

    echo "Waiting for Fuel Master to bootup and get IP..."
    FM_IP=$(wait_for_fm "$XS_HOST" "Fuel$FUEL_VERSION")
    [ -z "$FM_IP" ] && echo "Fuel Master IP obtaining timeout" && exit -1

    sshpass -p "$FM_PWD" ssh-copy-id -o StrictHostKeyChecking=no root@$FM_IP

    # if FM was restored from XVA, let's make need change and create snapshot.
    if [ "$restored_from" = "XVA" ]; then
        fresh_fm
        create_snapshot "$fm_name" "$fm_snapshot"
    fi
}

function create_node {
	# Create a node server(compute/controller node) with given memory, disk and NICs
	local xs_host="$1"
	local vm="$2"
	local mem="$3"
	local disk="$4"
	local cpu="$5"
	local ixe_nfs="$6"
	local ixe_iso="$7"

	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux

	vm="'$vm'"
	mem="'$mem'"
	disk="'$disk'"
	cpu="'$cpu'"
	ixe_nfs="'$ixe_nfs'"
	ixe_iso="'$ixe_iso'"

	ipxe_sr=$(xe sr-list name-label=ipxe --minimal)
	if [ -z "$ipxe_sr" ]; then
		ipxe_sr=$(xe sr-create type=iso content-type=iso device-config:location=$ixe_nfs name-label=ipxe)
		sleep 5
	fi

	template="Other install media"

	vm_uuid=$(xe vm-install template="$template" new-name-label="$vm")

	localsr=$(xe pool-list params=default-SR --minimal)
	extra_vdi=$(xe vdi-create \
		name-label=xvdb \
		virtual-size="${disk}GiB" \
		sr-uuid=$localsr type=user)
	vbd_uuid=$(xe vbd-create vm-uuid=$vm_uuid vdi-uuid=$extra_vdi device=0)

	xe vm-memory-limits-set \
		static-min=${mem}MiB \
		static-max=${mem}MiB \
		dynamic-min=${mem}MiB \
		dynamic-max=${mem}MiB \
		uuid=$vm_uuid

	xe vm-cd-add uuid=$vm_uuid device=1 cd-name=$ixe_iso
	xe vm-param-set uuid=$vm_uuid VCPUs-max=$cpu
	xe vm-param-set uuid=$vm_uuid VCPUs-at-startup=$cpu
	xe vm-param-set uuid=$vm_uuid HVM-boot-params:order=dc
	'
}

function add_vif {
	local xs_host="$1"
	local vm="$2"
	local network="$3"
	local device="$4"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	vm="'$vm'"
	network="'$network'"
	device="'$device'"

	vm_uuid=$(xe vm-list name-label="'$vm'" --minimal)
	network=${network//Network /Pool-wide network associated with eth}
	network_uuid=$(xe network-list name-label="$network" --minimal)
	xe vif-create network-uuid=$network_uuid vm-uuid=$vm_uuid device=$device
	'
}

function add_himn {
	# Add HIMN to given compute node and return the Mac address of the added NIC
	local xs_host="$1"
	local vm="$2"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'
	set -eux
	vm="'$vm'"
	network=$(xe network-list bridge=xenapi minimal=true)
	vm_uuid=$(xe vm-list name-label="'$vm'" --minimal)

	vif=$(xe vif-list network-uuid=$network vm-uuid=$vm_uuid --minimal)
	if [ -z "$vif" ]; then
		vif=$(xe vif-create network-uuid=$network vm-uuid=$vm_uuid device=9 minimal=true)
	fi

	mac=$(xe vif-list uuid=$vif params=MAC --minimal)
	xe vm-param-set xenstore-data:vm-data/himn_mac=$mac uuid=$vm_uuid
	'
}

function wait_for_fm {
	# Wait for fuel master booting and return its IP address
	local xs_host="$1"
	local fm_name="$2"

	local fm_ip
	for i in {0..60}; do
		fm_networks=$(ssh -qo StrictHostKeyChecking=no root@$xs_host \
		'xe vm-list name-label="'$fm_name'" params=networks --minimal')
		fm_ip=$(echo $fm_networks | egrep -Eo "1/ip: ([0-9]+\.){3}[0-9]+")
		if [ -n "$fm_ip" ]; then
			echo ${fm_ip: 5}
			return
		fi
		sleep 10
	done
}

function prepare_centos_repo_and_secret_key {
    # Create CentOS base repo and import secret key for building supplemental packages
    local fm_ip="$1"
    local gpg_secret_key_url="$2"

    ssh -qo StrictHostKeyChecking=no root@$fm_ip \
    '
    set -e
    mkdir -p /tmp/secret_keys
    wget "'$gpg_secret_key_url'" -O /tmp/secret_keys/openstack.secret
    gpg --import /tmp/secret_keys/openstack.secret
    rm -rf /tmp/secret_keys

    rm -f /etc/yum.repos.d/centos-base.repo
    touch /etc/yum.repos.d/centos-base.repo
    cat <<EOF >"/etc/yum.repos.d/centos-base.repo"
[base]
name=CentOSBase
mirrorlist=http://mirrorlist.centos.org/?release=\$releasever&arch=\$basearch&repo=os&infra=\$infra
baseurl=http://mirror.centos.org/centos/\$releasever/os/\$basearch/
enabled=0
exclude=kernel kernel-abi-whitelists kernel-debug kernel-debug-devel kernel-devel kernel-doc kernel-tools kernel-tools-libs kernel-tools-libs-devel linux-firmware biosdevname centos-release systemd* stunnel kexec-tools ocaml*
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
EOF
    '
}

function start_node {
	# Boot up given node
	local xs_host="$1"
	local vm="$2"
	ssh -qo StrictHostKeyChecking=no root@$xs_host \
	'xe vm-start vm="'$vm'"'
}

function wait_for_nailgun {
	# Wait for nailgun service started until the fuel plugin can be installed
	local fm_ip="$1"

	local ready
	for i in {0..60}; do
		ready=$(ssh -qo StrictHostKeyChecking=no root@$fm_ip \
		'
		export FUELCLIENT_CUSTOM_SETTINGS="/etc/fuel/client/config.yaml"
		fuel plugins &> /dev/null
		echo $?
		')
		if [ "$ready" -eq 0 ]; then
			echo 0
			return
		fi
		sleep 10
	done
	echo 1
}

create_networks "$XS_HOST" "$NET1" "$NET2" "$NET3"

ensure_fm "Fuel$FUEL_VERSION" "$FM_SNAPSHOT" "$FM_MNT" "fuel$FUEL_VERSION.xva"

create_node "$XS_HOST" "Compute" "$NODE_MEM_COMPUTE" "$NODE_DISK_COMPUTE" "$NODE_CPU_COMPUTE" "$IXE_NFS" "$IXE_ISO"
add_vif "$XS_HOST" "Compute" "$NET1" 1
add_vif "$XS_HOST" "Compute" "$NET2" 2
add_vif "$XS_HOST" "Compute" "$NET3" 3
echo "Compute Node is created"
add_himn "$XS_HOST" "Compute"

echo "HIMN is added to Compute Node"
create_node "$XS_HOST" "Controller" "$NODE_MEM_CONTROLLER" "$NODE_DISK_CONTROLLER" "$NODE_CPU_CONTROLLER" "$IXE_NFS" "$IXE_ISO"
add_vif "$XS_HOST" "Controller" "$NET1" 1
add_vif "$XS_HOST" "Controller" "$NET2" 2
add_vif "$XS_HOST" "Controller" "$NET3" 3
echo "Controller Node is created"

echo "Begin to create centos repo and import secret key in FM"
prepare_centos_repo_and_secret_key "$FM_IP" "$GPG_SECRET_KEY_URL"

NAILGUN_READY=$(wait_for_nailgun "$FM_IP")
[ "$NAILGUN_READY" -ne 0 ] && echo "Nailgun test connection timeout" && exit -1

start_node "$XS_HOST" "Compute"
echo "Compute Node is started"
start_node "$XS_HOST" "Controller"
echo "Controller Node is started"

recreate_gateway "$XS_HOST" "$NET2"

