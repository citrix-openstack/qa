#!/usr/bin/env/python

import keystone_utils
import json
import logging
import unittest
import os
import random
import signal
import subprocess
import sys
import time
import XenAPI
import xmlrpclib

from novaclient.v1_1 import client

ALPHABET = "abcdefghijklmnopqrstuvwxyz0123456789"
ADMIN_AUTH_TOKEN = "999888777666"
# Give instances 6 mins to become active
MAX_ATTEMPTS = 72
# Give instance further 75 seconds to boot - Daucus is slow
BOOTUP_TIME = 75
# Give some time also to setup the ssh tunnel
TUNNEL_SETUP_TIME = 5
# VLAN IDs FOR TENANTS
PRIVATE_VLAN_IDS = range(101,200)

key_filename = '/root/.ssh/id_rsa.pub'
keystone_api_url = ""
keystone_auth_url = ""
networking_mode = "flat"
xenapi_url = "somewhere"
xenapi_pw = "xenroot"
bridge_interface = "eth3"
vm_spawn_max_attemps = MAX_ATTEMPTS
vm_boot_time = BOOTUP_TIME


def _get_id(content, item, value):
    data = json.loads(content)
    if data[item]['name'] == value:
        return data[item]['id']
    return None;
    
def gen_rnd_string(str_len=5):
    result = ""
    for item in random.sample(ALPHABET,str_len):
        result += item
    return result

def setup_tenants_and_users():
    tenants = []
    users = {}
    tenant_a = "tenant_" + gen_rnd_string()
    tenant_b = "tenant_" + gen_rnd_string()
    _, content = keystone_utils.create_tenant(tenant_a, ADMIN_AUTH_TOKEN,
                                              keystone_api_url)
    tenants.append(_get_id(content,'tenant', tenant_a))
    
    _, content = keystone_utils.create_tenant(tenant_b, ADMIN_AUTH_TOKEN,
                                              keystone_api_url)
    tenants.append(_get_id(content,'tenant', tenant_b))
    
    user_a = "user_" + gen_rnd_string()
    user_b = "user_" + gen_rnd_string()
    
    _, content = keystone_utils.create_user(tenants[0], user_a,
                                            ADMIN_AUTH_TOKEN,
                                            keystone_api_url,
                                            gen_rnd_string(4) + "@test.com",
                                            user_a)
    users[_get_id(content,'user', user_a)] = [user_a, tenants[0], tenant_a]

    _, content = keystone_utils.create_user(tenants[1], user_b,
                                            ADMIN_AUTH_TOKEN,
                                            keystone_api_url,
                                            gen_rnd_string(4) + "@test.com",
                                            user_b)
    users[_get_id(content,'user', user_b)] = [user_b, tenants[1], tenant_b]
    
    for user in users:
        keystone_utils.create_role_ref(user,  "4", users[user][1],
                                       ADMIN_AUTH_TOKEN, keystone_api_url)
    for tenant in tenants:
        keystone_utils.create_endpoint(tenant, 1, 
                                       ADMIN_AUTH_TOKEN, keystone_api_url)
        keystone_utils.create_endpoint(tenant, 2,
                                       ADMIN_AUTH_TOKEN, keystone_api_url)
        keystone_utils.create_endpoint(tenant, 3,
                                       ADMIN_AUTH_TOKEN, keystone_api_url)
        keystone_utils.create_endpoint(tenant, 4,
                                       ADMIN_AUTH_TOKEN, keystone_api_url)
        keystone_utils.create_endpoint(tenant, 5,
                                       ADMIN_AUTH_TOKEN, keystone_api_url)
    
    return tenants, users


def delete_tenants_and_users(tenant_ids, user_ids):
    for user in user_ids:
        keystone_utils.delete_user(user, ADMIN_AUTH_TOKEN, keystone_api_url)
    for tenant in tenant_ids:
        keystone_utils.delete_tenant(tenant, ADMIN_AUTH_TOKEN, keystone_api_url)


def _execute(command):
    log = logging.getLogger( "guest_networking.test_guest_networking" )
    log.debug("Executing: %s...",command)
    env = os.environ.copy()
    process = subprocess.Popen(command,
                               shell=True,
                               stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               env=env)
    log.debug( "...Done! Errorcode=%s", process.returncode)    
    return process

    
def execute_and_return(command):
    process = _execute(command)
    return process.pid


def execute(command):
    process = _execute(command)
    (out, err) = process.communicate()
    return (out, err, process.returncode)

def create_private_network(label, tenant_id, vlan):
    print "tenant_id:%s", tenant_id
    octet = int(tenant_id) % 255
    command="nova-manage network create --label %s "\
            "--fixed_range_v4 10.0.%s.0/24 --num_networks=1 "\
            "--network_size=128 --vlan=%s --project_id=%s" \
            %(label, octet, vlan, tenant_id)
    (_, _, code) = execute(command)
    return code

def delete_private_network(tenant_id):
    print "tenant_id:%s", tenant_id
    octet = int(tenant_id) % 255
    command="nova-manage network modify "\
            "--fixed_range=10.0.%s.0/24 "\
            "--disassociate-project"\
            %octet
    (_, _, code) = execute(command)            
    command="nova-manage network delete "\
            "--fixed_range 10.0.%s.0/24 "\
            %octet
    (_, _, code) = execute(command)
    return code

def authenticate_user(user, pw, tenant):
    log = logging.getLogger( "guest_networking.test_guest_networking" )
    log.debug("Authenticating user %s to keystone...", user)
    tenant_client =  client.Client(user, pw, tenant,
                                    keystone_auth_url)
    tenant_client.authenticate()
    log.debug("...Done!")
    keys = tenant_client.keypairs.list()
    key_name = 'key_%s' % tenant
    key_exists = any([key.name==key_name for key in keys])
    if not key_exists:
        log.debug("Creating keypair for %s...", user)
        key_file=open(key_filename + ".pub")
        key_content=key_file.read()
        tenant_client.keypairs.create(key_name, key_content)
        log.debug("...Done!")
    return tenant_client, key_name


def remote_execute(command, host, key):
    (out, err, code) = execute("ssh -o stricthostkeychecking=no -i %s "
                               "root@%s %s" %(key, host, command))
    return (out, err, code)
    
    
def do_remote_ping(host, dst_ip):
    log = logging.getLogger( "guest_networking.test_guest_networking" )
    # We need this because of OS-849
    (_, _, code) = remote_execute("ls", host, key_filename)
    if code == 255:
        raise Exception("WARNING (OS-849): The key was probably " \
                        "not injected into the instance, " \
                        "cannot perform ping!")

    (out, err, code) = remote_execute("ping -q -c4 %s | "
                                      "tail -n2 | head -n1 | "
                                      "awk {'print $1\":\"$4'}" %dst_ip,
                                      host, key_filename)
    #parse output
    (sent, received) = out.split(':')
    if sent.strip() != received.strip():
        log.debug("Error: %s packets sent, %s packets received"
                  %(sent, received))
        return False
    return True


def wait_for_instances(instances, client):
    count = 0
    all_active = False
    fail_test = False
    reason = "Ok"
    
    while not all_active and not fail_test and \
          count < vm_spawn_max_attempts:
        time.sleep(5)
        status = []
        for instance in instances:
            instance=client.servers.get(instance)
            status.append(instance.status)
        all_active = all([item=='ACTIVE' for item in status])
        fail_test = any([item=='ERROR' for item in status]) 
        count = count + 1

    if fail_test:
        reason = "At least one instance failed to spawn"
    if count == vm_spawn_max_attempts:
        fail_test = True
        reason = "Instances not active after %d seconds" \
                 %(vm_spawn_max_attempts * 5)
    return (fail_test, reason)


def find_network_with_bridge_or_name(session, bridge):
    """
    Return the network on which the bridge is attached, if found.
    The bridge is defined in the nova db and can be found either in the
    'bridge' or 'name_label' fields of the XenAPI network record.
    """
    expr = 'field "name__label" = "%s" or ' \
           'field "bridge" = "%s"' % (bridge, bridge)
    networks = session.xenapi.network.get_all_records_where(expr)
    if len(networks) == 1:
        return networks.keys()[0]
    elif len(networks) > 1:
        raise Exception(_('Found non-unique network'
                          ' for bridge %s') % bridge)
    else:
        raise Exception(_('Found no network for bridge %s') % bridge)


def verify_bridge(url, password, guest_network, device=None, uuid=None,
                  name=None, is_worker=False, vlan_mode = False):
    # We'll use xenapi on guest installer network
    log = logging.getLogger( "guest_networking.test_guest_networking" )
    result = False
    session = XenAPI.Session(url)
    session.xenapi.login_with_password('root', password)        
    try:
        vm_ref = None
        if uuid:
            vm_ref = session.xenapi.VM.get_by_uuid(uuid)
        else:
            vm_refs = session.xenapi.VM.get_by_name_label(name)
            if len(vm_refs) == 0:
                # The name passed does not correspond to any name-label
                #look for it  xenstore_data
                vm_refs = session.xenapi.VM.get_all()
                for vmr in vm_refs:
                    # nobody should delete our VMs in the meanwhile...
                    vm_rec = session.xenapi.VM.get_record(vmr)
                    xs_data = vm_rec['xenstore_data']
                    if xs_data.get('vm-data/hostname', None) == name:
                        vm_ref = vmr
                        break
            else:
                vm_ref = vm_refs[0]
        # Make sure we found a reference to the VM
        if not vm_ref:
            return False
        vm_record = session.xenapi.VM.get_record(vm_ref)
        for vif_ref in vm_record['VIFs']:
            vif_record = session.xenapi.VIF.get_record(vif_ref) 
            if device is None or vif_record['device'] == device:
                # fetch network for vif
                net_record = session.xenapi.network.get_record(
                                                    vif_record['network'])
                # either name or bridge must be equal to 
                # the value for guest network bridge
                # unless we are in VLAN mode
                if is_worker==True or vlan_mode == False:
                    result = net_record['bridge'] == guest_network or \
                             net_record['name_label'] == guest_network
                else:
                    #E MO SO CAZZI
                    # Get PIF record for network's PIF
                    pif_rec = session.xenapi.PIF.get_record(
                                                 net_record['PIFs'][0])
                    # Must be a VLAN PIF (VLAN!=-1)
                    if pif_rec['VLAN'] == -1:
                        return False 
                    # PIF for guest_network must use same device 
                    guest_network_ref =\
                        find_network_with_bridge_or_name(session,
                                                         guest_network)
                    guest_network_rec = session.xenapi.network.get_record(
                                                       guest_network_ref)
                    guest_network_pif_rec = session.xenapi.PIF.get_record(
                                                guest_network_rec['PIFs'][0])
                    result = (guest_network_pif_rec['device'] ==\
                              pif_rec['device'])
                
        return result
    except XenAPI.Failure:
        log.debug("MUY DOLORE")
        # Raise exception only if we are looking for the worker VPX
        # as we expect the instance to be not found on (n-1) hosts
        if is_worker:
            raise
    finally:
        session.xenapi.session.logout()


class GuestNetworkingTestCase(unittest.TestCase):
    
    users = {}
    tenants = []
    instances_to_cleanup = {}
    log = logging.getLogger( "guest_networking.test_guest_networking" )    
    
    def setUp(self):
        # prepare users for keystone
        self.log.debug("Running %s", self._testMethodName)
        self.log.debug( "Setting up tenants and users...") 
        self.tenants, self.users = setup_tenants_and_users() 
        self.log.debug("...Done!")
        user1_id = self.users.keys()[0]
        (self.tenant1_client, self.tenant1_key) = \
            authenticate_user(self.users[user1_id][0],
                              self.users[user1_id][0],
                              self.users[user1_id][2])
        user2_id = self.users.keys()[1]
        (self.tenant2_client, self.tenant2_key) = \
            authenticate_user(self.users[user2_id][0],
                              self.users[user2_id][0],
                              self.users[user2_id][2])
        self.instances_to_cleanup = {}
        # Note: in vlan mode we will want to test network isolation as well
        if networking_mode.startswith('vlan'):
            self.log.debug("Creating private tenant networks")
            create_private_network("net_%s" %self.users[user1_id][0],
                                   user1_id,
                                   PRIVATE_VLAN_IDS[0])
            create_private_network("net_%s" %self.users[user2_id][0],
                                   user2_id,
                                   PRIVATE_VLAN_IDS[1])
            self.log.debug("...Done!")
        
    
    def tearDown(self):
        self.log.debug( "Deleting instances...")
        for tenant in self.instances_to_cleanup:
            for instance in self.instances_to_cleanup[tenant]:
                tenant.servers.delete(instance)
        self.log.debug("...Done!")
        self.log.debug("Removing tenants and users...")
        #delete_tenants_and_users(self.tenants, self.users)
        #self.log.debug("...Done!")
        #time.sleep(20)
        if networking_mode.startswith('vlan'):
            self.log.debug("Removing private tenant networks")
            for user in self.users:
                delete_private_network(user)
            self.log.debug("...Done!")
        self.log.debug("%s Completed", self._testMethodName)            
        # this should work around OS-848
        time.sleep(5)

    def test_01_verify_bridges(self):
        """ Verify whether instances and nova-network's bridge interface
            sit on the same XenServer bridge. 
            The aim of this test is to verify basic connectivity has been
            properly configured
        """
        self.log.debug("Running test 01_verify_bridges")

        self.log.debug("Spawning an instance for tenant_1")
        instance = self.tenant1_client.servers.create(
                        name="test-01-%s" %gen_rnd_string(),
                        image=3, flavor=1, key_name=self.tenant1_key)
        self.instances_to_cleanup[self.tenant1_client] = (instance,)
        self.log.debug( "Waiting for tenant_1 instance to boot...")
        (fail_test, reason) = wait_for_instances((instance,),
                                                  self.tenant1_client)
        self.assertEqual(fail_test, False, 
                         "Unable to spawn instance: %s" % reason)
        # some more time to make sure it boots up
        time.sleep(vm_boot_time)
        self.log.debug("...Done!")
        
        # Find network associated with guest network bridge or name 
        if networking_mode != 'flat':
            # Grab bridge for VIF associated with BRIDGE_INTERFACE
            # Remember: this test is supposed to be executed on
            # a network worker
            device = bridge_interface[3:]
            (uuid, _, _) = execute('cat /sys/hypervisor/uuid')
            uuid = uuid.strip()
            result = verify_bridge(xenapi_url, xenapi_pw, guest_net, device,
                                   uuid=uuid, is_worker=True)
            self.assertEqual(result, True, 
                             "The bridge interface on the network "
                             "node has not been configured on the "
                             "appropriate bridge %s" %guest_net)
        
        # Find instance - note it might be on a different host
        instance=self.tenant1_client.servers.get(instance)

        # Grab name for instance
        instance_name=instance._info['name']
        # match it on output from nova-manage vm list
        (out, _, _) = execute("nova-manage vm list | "\
                              "grep %s | awk {'print $2'}" %instance_name)
        host_id = out.strip()
        # Python client does not return the host for an instance
        # Create a proxy to geppetto service (master's name is always 'master'
        proxy = xmlrpclib.ServerProxy("http://master:8080/openstack/geppetto/v1")
        # Get all compute workers, and for each worker find relevant HOST ID
        # Now we know on which worker the instance has been spawn
        # Tunnel into the worker, and do verify_bridge
        compute_workers = proxy.Node.get_by_role('openstack-nova-compute')
        compute_worker_details = proxy.Node.get_details(compute_workers)
        for worker in compute_workers:
            worker_id = compute_worker_details[worker]\
                                              ['node_overrides']['HOST_GUID']
            if  worker_id == host_id:
                #Found it!
                localport = random.randint(8100,8200)
                # We tunnell into the compute worker for accessing xapi
                # xapi won't be listening on management interface
                self.log.debug("Creating tunnel to compute worker %s...", worker)
                pid = execute_and_return("ssh -i /root/.ssh/key_worker "
                                         "-o stricthostkeychecking=no " 
                                         "-n -N -L %s:169.254.0.1:80 "
                                         "root@%s" % (localport,worker))
                self.log.debug("...Done! Pid:%s", pid)
                # A few seconds to make sure the tunnel's up
                time.sleep(TUNNEL_SETUP_TIME)
                result = verify_bridge("http://127.0.0.1:%s" %localport, xenapi_pw,
                                       guest_net, name=instance_name,
                                       vlan_mode = networking_mode.startswith('vlan'))
                self.log.debug("Result from validation for this worker is:%s", result)
                os.kill(pid, signal.SIGKILL)
                self.log.debug( "Tunell to %s closed", worker)
                self.assertEqual(result, True, 
                                 "The bridge interface on the instance "
                                 "has not been configured on the "
                                 "appropriate bridge %s" %guest_net)
                if result:
                    return

        # If we end up here, the VM was not found
        self.fail("Unable to find the instance %s on any compute worker")

    def test_02_ping_from_gateway(self):
        """ Verify whether the gateway can reach an instance.
            The aim of this test is to verify the correctenss of IP
            configuration on the instances and the gateway
        """
        if networking_mode.startswith('flat'):
            self.log.debug("Sorry cannot perform this test in Flat mode")
            return
        self.log.debug("Running test_03_ping_from_gateway")
        self.log.debug("Spawning instance for tenant_1")
        instance = self.tenant1_client.servers.create(
                        name="test-02-%s" %gen_rnd_string(),
                        image=3, flavor=1, key_name=self.tenant1_key)
        self.instances_to_cleanup[self.tenant1_client] = (instance,)
        self.log.debug( "Waiting for tenant_1 instance to boot...")
        (fail_test, reason) = wait_for_instances((instance,),
                                                  self.tenant1_client)
        self.assertEqual(fail_test, False, 
                         "Unable to spawn instance: %s" % reason)
        self.log.debug("...Done!")
        # some additional time to ensure it's up!
        time.sleep(vm_boot_time)        
        # NOTE: ignore multi-homing on guest instances
        self.log.debug("...Done!")
        instance = self.tenant1_client.servers.get(instance)
        expected_ips = []
        for address in instance.addresses:
            expected_ips.append(instance.addresses[address][0]['addr'])
        self.log.debug("Expected IPs: %s", expected_ips)
        # Ping IP, grab reply
        for ip in expected_ips:
            (out, err, code) = execute("ping -q -c4 %s | " \
                                       "tail -n2 | head -n1 | " \
                                       "awk {'print $1\":\"$4'}" %ip)
            if code!=0:
                self.log.debug( "Error occured during ping: %s", err)
            #parse output
            (sent, received) = out.split(':')
            self.log.debug("Ping results: %s packets sent, %s packets received" 
                  % (sent, received))
            if sent.strip() != received.strip():
                fail_test = True
        self.assertEqual(fail_test, False, "Unable to ping instance's ip(s)")

    def test_06_verify_ip_configuration(self):
        """ Verify whether the IP configuration matches the expected one.
            In flat mode, this should verify IP configuration 
            has been properly injected.
            In flatdhcp and VLAN mode this should verify IP 
            configuration has been acquired from DHCP.
        """
        self.log.debug("Running test_02_verify_ip_configuration")
        if networking_mode.startswith('flat'):
            # We need to create a fake VIF on this node for
            # doing ssh into the instance
            self.log.debug("Sorry not available in flat mode at this time")
            return
        # Spawn an instance
        self.log.debug("Spawning instance for tenant_1")
        instance = self.tenant1_client.servers.create(
                        name="test-06-%s" %gen_rnd_string(),
                        image=3, flavor=1, key_name=self.tenant1_key)
        self.instances_to_cleanup[self.tenant1_client] = (instance,)
        self.log.debug("Waiting for tenant_1 instance to boot...")
        (fail_test, reason) = wait_for_instances((instance,),
                                                  self.tenant1_client)
        self.assertEqual(fail_test, False, 
                         "Unable to spawn instance: %s" % reason)
        self.log.debug("...Done!")
        time.sleep(vm_boot_time)
        #ssh into instance and grab /etc/network/interfaces content
        instance=self.tenant1_client.servers.get(instance)
        # Grab instance's xenserver's uuid by ssh-into into it
        first_address = instance.addresses.keys()[0]
        instance_ip = instance.addresses[first_address][0]['addr']        
        #Do this and grab error code because of OS-849
        (_, _, code) = remote_execute("cat /etc/network/interfaces",
                                          instance_ip, key_filename)
        if code == 255:
            self.log.debug( "WARNING(OS-849): The key was not injected "\
                   "into the instance, cannot access /etc/network/interfaces!")
            return
        (out, err, code) = remote_execute("cat /etc/network/interfaces | "
                                          "grep iface | awk {'print $2\":\"$4'}",
                                          instance_ip, key_filename)
        self.assertEqual(code, 0, "Unable to ssh into the instance. This "
                                 "indicates a problem with guest instance "
                                 "networking. Error message:%s" %err)
        expected_mode ='dhcp'
        if networking_mode.startswith('flat'):
            expected_mode = 'static'
        
        #verify that configuration consistent with networking mode
        found = False
        for line in out.split('\n'):
            if line:
                (interface, mode) = line.split(':')
                if interface.startswith('eth'):
                    found = True
                    self.log.debug("Interface mode: %s", mode)
                    self.log.debug("Expected mode: %s", expected_mode)
                    self.assertEqual(mode, expected_mode,
                                     "Interface is configured in %s mode."
                                     "Was expecting %s mode"
                                     %(mode, expected_mode))
        self.assertEqual(found, True, "No ethernet interface found")
    
if __name__ == "__main__":
    key_filename = "/root/.ssh/" + sys.argv[1]
    keystone_auth_url = "http://" + sys.argv[2] + ":5000/v2.0/"
    keystone_api_url = "http://" + sys.argv[2] + ":35357/v2.0/"
    networking_mode = sys.argv[3]
    guest_net = sys.argv[4]
    bridge_interface = sys.argv[5]
    xenapi_url = sys.argv[6]
    xenapi_pw = sys.argv[7]
    if len(sys.argv)>8:
        vm_spawn_max_attempts = int(sys.argv[8]) / 5
    if len(sys.argv)>9:
        vm_boot_time = int(sys.argv[9])
    logging.basicConfig( stream=sys.stdout )
    logging.getLogger( "guest_networking.test_guest_networking" ).\
            setLevel( logging.DEBUG )
    unittest.main(argv=[sys.argv[0]])

