#!/bin/bash

#
# Create two VPXs on this host, one master, one slave, and join them up with
# a local management network.
#

set -eux

thisdir=$(dirname "$0")

. "$thisdir/../common-esx41.sh"
. "$thisdir/../common-ssh.sh"

keyfile=~/.ssh/id_rsa
vpx_password="citrix"


echo "thisdir inside $0 is --> " $thisdir
 
server="$1"
password="$2"
numports="$3"
build_url="$4"
devel="$5"

cd "$thisdir"

echo "Inside install_vpxs_esx41.sh, build_url is --> " $build_url

echo "Creating a directory to host ESX VPX image files"

image_hosting_dir=$thisdir"/esx_image_files/"

rm -rf $image_hosting_dir
mkdir -p $image_hosting_dir

fetch_vpx_images_esx41 "$build_url" "$devel" "$image_hosting_dir"

#clean_host

# Go ahead and create a master VPX on the host.

if $devel
then
  filename="os-vpx-devel"
else
  filename="os-vpx"
fi

# First create the master vpx.
cmd_out=`python $thisdir"/../esx_41_scripts/install-os-vpx-esxi.py" \
	-H $server -P $password \
	-f $image_hosting_dir"/"$filename".ovf" \
	-M "true" -N "true"`
#Retrieve the ip allocated to the master vpx.
master_vpx_ip=$(echo $cmd_out |
                sed -ne 's,^.*Allocating IP \(.*\) to VM.*$,\1,p')
echo "master_vpx_ip is --> " $master_vpx_ip

vpx_ip_addr_list="$master_vpx_ip"

echo "Will wait for 10 seconds before creating slave VPXs"
echo "This is to allow configuration of master to go through"

sleep 10

echo "Creating slave VPXs on ESX server $server"

# Each time we create a slave vpx, we note its IP address, and add it to a list.
# When we're done creating all slaves VPXs, we inject the visdk files to each.

for i in $(seq 1 8)
do
    cmd_out=`python $thisdir"/../esx_41_scripts/install-os-vpx-esxi.py" \
	-H $server -P $password \
	-f $image_hosting_dir"/"$filename".ovf"`
    #Retrieve the ip allocated to the master vpx.
    slave_vpx_ip=$(echo $cmd_out |
                   sed -ne 's,^.*Allocating IP \(.*\) to VM.*$,\1,p')
    echo "slave vpx ip is --> " $slave_vpx_ip
    # Append it to the ip list.
    vpx_ip_addr_list="$vpx_ip_addr_list $slave_vpx_ip"
    # Put a sleep of 3 seconds between each creation.
    # This does add delays, but we're not testing for performance here.
    # Of course, we may end up missing race conditions. We can make
    # these sleep intervals variable later.
    sleep 3
    # Now 
done

# Finally, copy over the visdk files to each vpx.

# First, generate keyfile if it's not already present on jenkins test m/c.
if [ ! -f $keyfile ]
then
    gen_key
fi

# Next upload the generated ssh keys to the ESX host.
# This sets up passwordless ssh betwen
# jenkins test m/c and the ESX host.
upload_key $server $password $keyfile

# Next, establish a tunnel between this jenkins test m/c and each
# VPX through the ESX Host.. We need to reach port 22 of the vpx.
vpx_tunnel_port=22

# For every vpx, we need to do the following -
# Setup a tunnel between the jenkins test machine 
# and the VPX, via the ESX host. We need passwordless
# login, so set up keys between the jenkins test machine
# and the ESX Host, and between jenkins test machine
# and the VPX.

for vpx_ip in $vpx_ip_addr_list; do
    tunnel_port=
    establish_tunnel "$vpx_ip" $vpx_tunnel_port $server tunnel_port 
    # Now setup ssh keys between this jenkins m/c and the VPX. 
    upload_key_to_vpx "127.0.0.1" $vpx_password $keyfile $tunnel_port
    # Now, we have a tunnel to the VPX, and we have uploaded the keys as well.
    # We shall now invoke rsh to mkdir /etc/openstack/visdk/ on the VPX.
    rsh -p $tunnel_port root@127.0.0.1 "mkdir -p /etc/openstack/visdk"
    # Finally copy over the xsd and wsdl files to the vpx.
    for file in `ls $thisdir"/../esx_41_scripts/vpx_visdk_files/"`; do
	scp -P $tunnel_port $thisdir"/../esx_41_scripts/vpx_visdk_files/"$file root@127.0.0.1:/etc/openstack/visdk/
    done
done

# This ends creating and setting up VPXs.
