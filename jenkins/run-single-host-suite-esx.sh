#!/bin/bash


############
# This script is under editing. Do NOT use for your testing purposes!!!
############

set -eux

thisdir=$(dirname $(readlink -f "$0"))

. "$thisdir/common-esx41.sh"

devel="${Devel-false}"
autosite="${AUTOSITE-false}"
password="${Password-$XS_ROOT_PASSWORD}"

if $autosite
then
  autosite_server="$Server"
fi

enter_jenkins_test

server="${Server-$TEST_ESX_SINGLE_TEST_SERVER}"
smtp_svr="${MailServer-$TEST_MAIL_SERVER}"
usr_mail="${EmailAddress-$TEST_MAIL_ACCOUNT}"
password="${Password-$TEST_ESX_SINGLE_TEST_PASSWORD}"
num_ports="${NumPorts-$TEST_ESX_SINGLE_TEST_NUMPORTS}"

# First set the build_url.
#build_url=$build_url"/os-vpx"
#echo "build_url here is --> " $build_url


# First, set up the directory structure and pull ESX files/scripts.
mkdir -p $thisdir"/esx_41_scripts/deploy_vpx/vmwareapi"
fetch_esx41_scripts $build_url $thisdir"/esx_41_scripts/"
rc=$?
if [ $rc -ne 0 ]; then
	echo "Failed to pull ESX scripts"
	exit $rc
fi

# Next, we need to modify the flags.py and vimService.wsdl
# files that we pulled in. This is needed to setup this jenkins
# node itself to be able to issue calls to the ESX Host.
setup_local_node_for_esx41_communication
rc=$?
if [ $rc != 0 ]; then
	echo "Error: Failed to setup local node `hostname` for communication with esx!"
	exit $rc
else
	echo "Successfully setup local jenkins node for communication with ESX"
fi


# Clean up any VPX instances that may be on the server.
python $thisdir"/esx_41_scripts/uninstall-os-vpx-esxi.py" $server $password
rc=$?
if [ $rc != 0 ]; then
	echo "Error: Failed to cleanup VPXs on ESX server $server !"
	exit $rc
else
	echo "Successfully cleaned up VPXs on ESX server $server "
fi

# Sleep for around 10 seconds to give ESX time to clean up.
echo "Sleeping for 5 seconds to give ESX time to clean up."
sleep 5 

# Next, clean up any VPX networking elements that may exist on the ESX server, so
# that we start with a clean slate. If we attempt to cleanup networking before
# cleaning up the VPXs, network elements would be in use if there any any stale
# VPXs around, and hence un-deletable.
python $thisdir"/esx_41_scripts/delete_esxi_networking.py" -H $server -P $password
rc=$?
if [ $rc != 0 ]; then
	echo "Error: Failed to cleanup networking on ESX server $server !"
	exit $rc
else
	echo "Successfully cleaned up network configuration on ESX server $server "
fi

# Sleep for around 5 seconds to give ESX time to clean up.
echo "Sleeping for 5 seconds to give ESX time to clean up."
sleep 5

# Then, setup the networking on the ESX host. This is a single node test suite,
# so the options are slightly different from what would be used if running tests
# for a multihost env.

# Call the python script ./esx_scripts/setup_esxi_networking.py to do this.
python $thisdir"/esx_41_scripts/setup_esxi_networking.py" -H $server -P $password -n $num_ports
rc=$?
if [ $rc != 0 ]; then
	echo "Error: Failed to setup networking on ESX server $server !"
	exit $rc
else
	echo "Successfully setup network configuration on ESX server $server "
fi

# Invoke run-geppetto-test-esx41.sh. This script copies over
# the required .ovf, .mf and .vmdk files to a temp staging directory,
# and installs vpxs on the remote ESX server. It installs 9 VPXs, one
# master, and the others slaves, after it.
"$thisdir/run-geppetto-test-esx41.sh"


#############

echo "Testing OpenStack Dashboard on: $server."
"$thisdir/run-esx-dashboard-test.sh"

echo "Testing OpenStack Glance on: $server."
"$thisdir/run-esx-glance-stream-test.sh"

# Finally, run cleanup to clear all contents of the node. Do this if the 
