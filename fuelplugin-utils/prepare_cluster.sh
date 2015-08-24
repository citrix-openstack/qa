source localrc
set -x
ALL_NODES="$CONTROLLER_NODES,$COMPUTE_NODES,$STORAGE_NODES"

echo "Creating VMs"

for HOST_NODE in ${ALL_NODES//,/ }
do
	_HOST_NODE=(${HOST_NODE//// })
	HOST=${_HOST_NODE[0]}
	NODE=${_HOST_NODE[1]}

	sshpass -p $XEN_PASSWORD ssh -o StrictHostKeyChecking=no $XEN_ROOT@$HOST \
'set +x
guest_name="'$NODE'"
memory="'$NODE_MEMORY'"
disksize="'$NODE_DISKSIZE'"
tname="Other install media"

vm_uuid=$(xe vm-install template="$tname" new-name-label="$guest_name")

localsr=$(xe pool-list params=default-SR minimal=true)
extra_vdi=$(xe vdi-create \
	name-label=xvdb \
	virtual-size="${disksize}GiB" \
	sr-uuid=$localsr type=user)
vbd_uuid=$(xe vbd-create vm-uuid=$vm_uuid vdi-uuid=$extra_vdi device=0)
xe vm-cd-add vm=$vm_uuid device=1 cd-name="xs-tools.iso"

xe vm-memory-limits-set \
    static-min=${memory}MiB \
    static-max=${memory}MiB \
    dynamic-min=${memory}MiB \
    dynamic-max=${memory}MiB \
    uuid=$vm_uuid

eth0_uuid=$(xe vif-create network-uuid=$(xe network-list name-label="'"$NODE_ETH0"'" --minimal) vm-uuid=$vm_uuid device=0)
eth1_uuid=$(xe vif-create network-uuid=$(xe network-list name-label="'"$NODE_ETH1"'" --minimal) vm-uuid=$vm_uuid device=1)
eth0_mac=$(xe vif-param-get uuid=$eth0_uuid param-name=MAC)
xe vm-param-set uuid=$vm_uuid HVM-boot-params:order=ndc

echo "'$HOST'	'$NODE'	($eth0_mac) booted"
'
done
