xe_min()
{
  local cmd="$1"
  shift
  xe "$cmd" --minimal "$@"
}

find_network()
{
  result=$(xe_min network-list bridge="$1")
  if [ "$result" = "" ]
  then
    result=$(xe_min network-list name-label="$1")
  fi
  echo "$result"
}

find_template_name_by_other_config()
{
  local conf="$1"
  xe_min template-list other-config:"$conf" params=name-label
}

get_network_bridge()
{
  local filter="$1"
  result=$(xe_min network-list params=bridge bridge="$filter")
  if [ "$result" = "" ]
  then
    result=$(xe_min network-list params=bridge name-label="$filter")
  fi
  echo "$result"
}

get_bridge_by_other_config()
{
  local conf="$1"
  echo $(xe_min network-list params=bridge other-config:"$conf")
}

get_bridge_by_vm_and_device()
{
  local vm_uuid="$1"
  local device="$2"
  net_uuid=$(xe_min vif-list vm-uuid="$vm_uuid" device="$device" params=network-uuid)
  bridge=$(xe_min network-param-get param-name=bridge uuid="$net_uuid")  
  echo $bridge
}

destroy_vdi()
{
  local vbd_uuid="$1"
  local vdi_uuid=$(xe_min vbd-list uuid=$vbd_uuid params=vdi-uuid)
  xe vdi-destroy uuid=$vdi_uuid
}

destroy_vdis()
{
  local uuids="$1"
  IFS=,
  for u in $uuids
  do
    xe vdi-destroy uuid=$u
  done
  unset IFS
}

destroy_network()
{
  local net_uuid="$1"
  pif_uuid=$(xe_min network-param-get param-name=PIF-uuids uuid=$net_uuid)
  if [ $pif_uuid ] 
  then
    vlan_uuid=$(xe_min vlan-list untagged-PIF=$pif_uuid)
    xe vlan-destroy uuid=$vlan_uuid
  fi
  xe network-destroy uuid=$net_uuid
}

uninstall()
{
  local vm_uuid="$1"
  local power_state=$(xe_min vm-list uuid=$vm_uuid params=power-state)

  if [ "$power_state" != "halted" ]
  then
    echo -n "Shutting down VM... "
    xe vm-shutdown vm=$vm_uuid force=true
    echo "done."
  fi
  IFS=,
  for v in $(xe_min vbd-list vm-uuid=$vm_uuid)
  do
    destroy_vdi "$v"
  done
  unset IFS
  echo -n "Deleting VM... "
  xe vm-uninstall vm=$vm_uuid force=true >/dev/null
  echo "done."
}

get_ip()
{
  ip_addr=$(echo "$1" | sed -n "s,^.*"$2"/ip: \([^;]*\).*$,\1,p")
  echo "$ip_addr"
}

get_vm_uuid_by_role()
{
  local role="$1"
  echo $(xe_min vm-list power-state=running tags:contains="$role")
}

get_vm_uuid_by_other_config()
{
  local conf="$1"
  echo $(xe_min vm-list power-state=running other-config:"$conf")
}

get_any_vm_uuid_by_other_config()
{
  local conf="$1"
  echo $(xe_min vm-list other-config:"$conf")
}

get_vm_address()
{
  local vm_uuid="$1"
  local device="$2"
  networks=$(xe_min vm-param-get param-name=networks uuid="$vm_uuid")
  addr=$(get_ip "$networks" "$device")
  echo "$addr"
}

wait_for_vif_up()
{
  local vm_uuid="$1"
  local device="$2"
  local bridge="$3"
  local tries=600

  echo "Waiting for network configuration... "
  i=0
  while [ $i -lt $tries ]
  do
    ips=$(xe_min vm-list params=networks uuid=$vm_uuid)
    if [ "$ips" != "<not in database>" ]
    then
      nic_ip=$(get_ip "$ips" "$device")
      if [ "$nic_ip" != "" ]
      then
        echo "IP address for $bridge: $nic_ip"
        return 0
      fi
    fi
    sleep 10
    let i=i+1
  done
  [ $i -eq $tries ] && echo "IP address for $bridge: did not appear"
}

