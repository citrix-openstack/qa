import logging
import re
import sys
import time
import unittest
import xmlrpclib

SWIFT_DISK_SIZE = 10
SWIFT_HASH_PATH_SUFFIX = 'lota'
GLANCE_STORE = 'swift'
BRIDGE_INTERFACE = 'eth3'
GUEST_NW_VIF_MODE = 'noip'

def conditional_skip():
    """ Decorator for skipping a test according to preferences set by the
    user on the command line when the test run was launched
    """    
    def deco_conditional_skip(f):
        def f_conditional_skip(*args,**kwargs):
            testObject = args[0] # self in the test
            if hasattr(testObject, 'skip_list'):
                match=re.match("^test_([0-9][0-9]).*$",testObject._testMethodName)
                if len(match.groups())>0:
                    idx = match.group(1)
                    if idx in testObject.skip_list:
                        testObject.skipTest("Skipped by user")
                        return
            return f(*args, **kwargs)
        return f_conditional_skip
        
    return deco_conditional_skip

def read_rolemappings_file(filename):
    roles_file = open(filename)
    vpx_roles_data = roles_file.read().split('\n')
    vpx_roles = {}
    roles_vpx = {}
    for vpx in vpx_roles_data:
        if vpx != '':
            fields = vpx.split(' ')
            vpx_roles[fields[0]] = dict( host=fields[1],
                                         roles=fields[2:])
            for role in fields[2:]:
                if not role in roles_vpx:
                    roles_vpx[role] = []
                roles_vpx[role].append(fields[0])
    return vpx_roles, roles_vpx

class GeppettoAPISetupTestCase(unittest.TestCase):

    def setUp(self):
        self.log = logging.getLogger("guest_networking.setup_cloud")
        self.log.debug("Running %s", self._testMethodName)
        self.proxy = xmlrpclib.ServerProxy(master_url)

    @conditional_skip()
    def test_00_hypervisor_password(self):
        #set password
        self.proxy.Config.set("HAPI_PASS", xs_root_password)
        #TODO: remotely execute hapi_check on hypervisor
    
    @conditional_skip()
    def test_01_setup_rabbit_mysql(self):
        mysql_worker = "%s.%s" %(roles_vpx['mysqld'][0], dns_suffix)
        rabbit_worker = "%s.%s" %(roles_vpx['rabbitmq-server'][0], dns_suffix)
        self.log.debug("MySQL worker:%s", mysql_worker)
        self.log.debug("rabbit worker:%s", rabbit_worker)
        self.proxy.Compute.add_database(mysql_worker, {"MYSQL_PASS": "citrix"})
        self.proxy.Compute.add_message_queue(rabbit_worker)
        self.log.debug("test_01_setup_rabbit_mysql completed")
    
    @conditional_skip()
    def test_02_setup_identity(self):
        keystone_worker = "%s.%s" %(roles_vpx['openstack-keystone-auth'][0],
                                    dns_suffix)
        self.log.debug("Keystone worker:%s", keystone_worker)
        self.proxy.Identity.add_auth(keystone_worker, {})
        self.log.debug("test_02_setup_identity completed")
    
    @conditional_skip()
    def test_03_setup_object_store_and_imaging(self):
        storage_workers = [ "%s.%s" %(role, dns_suffix)
                           for role in roles_vpx['openstack-swift-container']]
        proxy_worker = "%s.%s" %(roles_vpx['openstack-swift-proxy'][0],
                                 dns_suffix)
        self.log.debug("Swift container workers:%s", storage_workers)
        self.log.debug("Swift proxy worker:%s", proxy_worker)
        
        disk_size = SWIFT_DISK_SIZE
        hash_suff = SWIFT_HASH_PATH_SUFFIX
        self.proxy.Config.set("SWIFT_HASH_PATH_SUFFIX", hash_suff)
        self.proxy.ObjectStorage.add_apis([proxy_worker], {})
        self.proxy.ObjectStorage.add_workers(storage_workers,
                                      {"SWIFT_DISK_SIZE_GB":disk_size})
        # wait for the tasks to start executing and populate the swift address
        time.sleep(30)
        glance_worker = "%s.%s" %(roles_vpx['openstack-glance-registry'][0],
                                  dns_suffix)
        config = {}
        config["GLANCE_STORE"] = GLANCE_STORE
        config["GLANCE_SWIFT_ADDRESS"] = proxy_worker
        self.proxy.Imaging.add_registry(glance_worker, config)
        self.log.debug("test_03_setup_object_store_and_imaging completed")
    
    @conditional_skip()
    def test_04_setup_api(self):
        api_worker = "%s.%s" %(roles_vpx['openstack-nova-api'][0], dns_suffix)
        scheduler_worker = "%s.%s" %(roles_vpx['openstack-nova-scheduler'][0],
                                     dns_suffix)
        self.proxy.Compute.add_apis([api_worker], {})
        self.proxy.Scheduling.add_workers([scheduler_worker], {})
        self.log.debug("test_04_setup_api completed")
        
    @conditional_skip()
    def test_05_setup_network(self):
        config = {}
        config['MODE'] = networking_mode.split('-')[0]
        self.log.debug("Configuring networking mode:%s", config['MODE'])
        config['GUEST_NETWORK_BRIDGE'] = guest_network_bridge
        config['BRIDGE_INTERFACE'] = BRIDGE_INTERFACE
        config['GUEST_NW_VIF_MODE'] = GUEST_NW_VIF_MODE
        if networking_mode.lower().endswith('ha'):
            config["MULTI_HOST"] = True
            self.log.debug("Performing HA setup")
            self.proxy.Network.configure_ha(config)
        else:
            config["MULTI_HOST"] = False
            # Pick first worker only
            network_worker = "%s.%s" %(roles_vpx['openstack-nova-network'][0], dns_suffix)
            self.log.debug("Network worker:%s", network_worker)
            self.proxy.Network.add_workers([network_worker], config)
        self.log.debug("test_05_setup_network completed")

    @conditional_skip()
    def test_06_setup_compute(self):
        # MUST ADD ALL THE WORKERS!!!
        compute_workers = [ "%s.%s" %(role, dns_suffix)
                           for role in roles_vpx['openstack-nova-compute']]
        self.log.debug("Compute workers:%s", compute_workers)
        self.proxy.Compute.add_workers(compute_workers, {})
        self.log.debug("test_06_setup_compute completed")
    
    @conditional_skip()
    def test_07_wait_for_stable_cloud(self):
        self.log.debug("Waiting for deployment to become stable")
        fqdns = self.proxy.Node.get_all()
        details=self.proxy.Node.get_details(fqdns)
        
        max_retries = 20
        retries = 0
        
        while True:
            details=self.proxy.Node.get_details(fqdns)
            all_stable = all([details[fqdn]['report_status']=='u'
                         for fqdn in fqdns])
            self.log.debug("All stable:%s", all_stable)
            if all_stable:
                break
            time.sleep(60)
            retries = retries + 1
            self.log.debug("retries:%s", retries)
            self.assertNotEqual(retries, max_retries,
                                "The cloud was unstable after %d seconds."
                                "Test failed"
                                %(max_retries*60))
        self.log.debug("test_07_wait_for_stable_cloud completed")
    
if __name__ == "__main__":
    master_url = '%s/openstack/geppetto/v1' % sys.argv[1]
    xs_root_password = sys.argv[2]
    vpx_roles_file = sys.argv[3]
    networking_mode = sys.argv[4]
    man_network_bridge = sys.argv[5]
    public_network_bridge = sys.argv[6]    
    guest_network_bridge = sys.argv[7]
    floating_ip_range = sys.argv[8]
    dns_suffix=sys.argv[9]
    logging.basicConfig( stream=sys.stdout )
    logging.getLogger("guest_networking.setup_cloud").\
            setLevel( logging.DEBUG )
    vpx_roles, roles_vpx = read_rolemappings_file(vpx_roles_file)
    unittest.main(argv=[sys.argv[0]])
