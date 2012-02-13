#!/usr/bin/env python

import unittest
import time
import sys
import common

selenium_url = "http://localhost:8080/"
selenium_port = 4444
xs_root_password = ''
guest_network = "--fixed_range_v4=10.0.0.0/24 --label private --bridge xenbr0"

class GeppettoTestCase(common.SeleniumTestCase):

    def setUp(self):
        self.skip_list = skip_list
        self.set_up_selenium(selenium_url, selenium_port)
        self._login()

    def tearDown(self):
        self._logout()
        self.stop_selenium()

    @common.retry(Exception, tries=12)
    def _login(self):
        sel = self.selenium
        sel.open("/")
        self.wait_for_page_to_load()
        sel.type("username", "root")
        sel.type("password", "citrix")
        sel.click("//form[@id='SubmitForm']/div[4]/a/div/div[1]")
        self.wait_for_page_to_load()

    @common.retry(Exception, tries=12)
    def _logout(self):
        sel = self.selenium
        sel.open("/")
        self.wait_for_page_to_load()
        sel.click("link=Logout")
        self.wait_for_page_to_load()

    def _click_next(self):
        self.selenium.click("//form[@id='SubmitForm']/div[3]/a/div/div[2]")

    def _check_back_at_install_checklist(self):
        self.selenium.click("link=List Nodes...")
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_00_hypervisor_password(self):
        sel = self.selenium
        sel.click("setup_hypervisor")
        self.wait_for_page_to_load()
        sel.type("id_password", xs_root_password)
        sel.type("id_repeat_password", xs_root_password)
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_01_setup_rabbit_mysql(self):
        sel = self.selenium
        sel.click("setup_rabbitmq_mysql")
        self.wait_for_page_to_load()
        # message queue: let's stick with the fifth node
        sel.select("id_worker", "index=5")
        vpx = sel.get_selected_label("id_worker")
        sel.click("//form[@id='SubmitForm']/div[3]/a/div")
        self.wait_for_page_to_load()
        # database: ensure we use the same one
        sel.select("id_worker", "label=%s" % vpx)
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_02_setup_identity(self):
        sel = self.selenium
        sel.click("setup_identity")
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=7")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_03_setup_object_store(self):
        sel = self.selenium
        sel.click("setup_object_store")
        self.wait_for_page_to_load()
        sel.type("id_hash_path_suffix", "test_hash_YaDaYaDAYAda")
        self._click_next()
        self.wait_for_page_to_load()
        sel.type("id_size", "10")
        self._click_next()
        self.wait_for_page_to_load()
        sel.add_selection("id_workers", "index=1")
        sel.add_selection("id_workers", "index=2")
        sel.add_selection("id_workers", "index=3")
        self._click_next()
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=5")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

        # wait for the tasks to start executing and populate the swift address
        time.sleep(30)

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_04_setup_imaging_service(self):
        sel = self.selenium
        sel.click("setup_imaging")
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=7")
        sel.click("id_default_storage_1")
        sel.click("//form[@id='SubmitForm']/div[2]/table/tbody/tr[2]/td/ul/li[2]/label")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_05_setup_api(self):
        sel = self.selenium
        sel.click("setup_api")
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=%s" % dashboard_node_index) # TODO - need a long term fix for multi-host test to find the dashboard
        self._click_next()
        self.wait_for_page_to_load()
        # Put the Console Proxy on the same node as the Compute API and
        # Dashboard.
        #sel.select("id_worker", "index=%s" % dashboard_node_index)
        #self._click_next()
        #self.wait_for_page_to_load()
        sel.select("id_worker", "index=6")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    def _flat_networking_setup(self):
        sel = self.selenium
        sel.click("setup_network")
        self.wait_for_page_to_load()
        sel.click("id=id_networking_mode_0")
        sel.click("css=a.button.button_w > div > div > img")
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=9")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    def _flat_dhcp_networking_setup(self):
        sel = self.selenium
        sel.open("/install_checklist")
        sel.click("id=setup_network")
        self.wait_for_page_to_load()
        # Select Flat DHCP (do not touch HA - assumes off by default)
        sel.click("id=id_networking_mode_1")
        self._click_next()
        self.wait_for_page_to_load()
        # Select worker
        sel.select("id=id_worker", "index=9")
        sel.click("css=a.button.button_w > div")
        self.wait_for_page_to_load()
        # Set host network to guest network bridge
        # Set iface on network node to eth2
        sel.type("id=id_host_network", guest_network_bridge)
        sel.click("id=id_network_type_2")
        sel.select("id=id_device", "label=eth3")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    def _flat_dhcp_ha_networking_setup(self):
        sel = self.selenium
        sel.open("/install_checklist")
        sel.click("id=setup_network")
        self.wait_for_page_to_load()
        # Select Flat DHCP and enable HA
        sel.click("id=id_networking_mode_1")
        sel.click("id=id_multi_host")
        self._click_next()
        self.wait_for_page_to_load()
        # No worker selection in HA mode
        # Set host network to guest network bridge
        # Set iface on network node to eth3
        sel.type("id=id_host_network", guest_network_bridge)
        sel.click("id=id_network_type_1")
        sel.select("id=id_device", "label=eth3")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_06_setup_network(self):
        if networking_mode == 'flat':
            self._flat_networking_setup()
        elif networking_mode == 'flatdhcp':
            self._flat_dhcp_networking_setup()
        elif networking_mode == 'vlan':
            raise NotImplementedError()
        elif networking_mode == 'flatdhcp-ha':
            self._flat_dhcp_ha_networking_setup()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_07_setup_volume(self):
        sel = self.selenium
        sel.click("setup_volume")
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=8")
        sel.select("id_storage_type", "label=Software iSCSI")
        self._click_next()
        self.wait_for_page_to_load()
        sel.type("id_disk_size", "10")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_08_setup_compute_worker(self):
        sel = self.selenium
        sel.click("setup_compute_worker")
        self.wait_for_page_to_load()
        sel.select("id_worker", "index=9")
        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_09_wait_till_setup_stable(self):
        sel = self.selenium
        sel.click("link=List Nodes...")
        self.wait_for_page_to_load()

        retry_count = 0
        max_retries = 15
        sleep_seconds = 60

        time.sleep(sleep_seconds)

        while True:
            sel.refresh()
            self.wait_for_page_to_load()

            if (not sel.is_text_present("(None)")) and \
               (not sel.is_text_present("changed")) and \
               (not sel.is_text_present("failed")) and \
               (not sel.is_text_present("pending")) and \
               sel.is_text_present("stable"):
                return

            print "Deployment not yet stable: re-tried (%s) times" % retry_count
            retry_count = retry_count + 1
            self.assertNotEqual(retry_count, max_retries)

            time.sleep(sleep_seconds)

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_10_create_network(self):
        sel = self.selenium
        sel.click("link=Create Networks...")
        self.wait_for_page_to_load()
        sel.type("id_command_line", guest_network)
        sel.click("//form[@id='SubmitForm']/div[3]/a/div")
        self.wait_for_page_to_load()

        # to prove we have got back to the install_checklist page
        sel.click("link=Create Networks...")
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_11_image_upload(self):
        sel = self.selenium
        sel.click("link=Upload Images...")
        self.wait_for_page_to_load(60)
        sel.type("id_disk_size", "5")
        self._click_next()
        self.wait_for_page_to_load(240)

        sel.type("id_label", "ubuntu")

        image_dir = "/images/GoldenImage/"
        sel.attach_file("id_machine", "file://%s/ubuntu-lucid.img" % image_dir) # NOTE: requires these files to be present on Jenkins machine
        sel.attach_file("id_kernel", "file://%s/vmlinuz-2.6.32-23-server" % image_dir)
        sel.attach_file("id_ramdisk", "file://%s/initrd.img-2.6.32-23-server" % image_dir)
        sel.click("//form[@id='SubmitForm']/div[3]/a/div/div[2]")
        self.wait_for_page_to_load(1200)

        sel.click("//form[@id='SubmitForm']/div[3]/a/div") # this is the image upload step        
        self.wait_for_page_to_load(1200)

        # to prove we have got back to the install_checklist page
        sel.click("link=Upload Images...")
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_12_windows_style_image_upload(self):
        sel = self.selenium
        sel.click("link=Upload Images...")
        self.wait_for_page_to_load(60)

        sel.type("id_label", "windows style image")

        image_dir = "/images/GoldenImage/"
        sel.attach_file("id_machine", "file://%s/vmlinuz-2.6.32-23-server" % image_dir)
        sel.click("//form[@id='SubmitForm']/div[3]/a/div/div[2]")
        self.wait_for_page_to_load(1200)

        sel.click("//form[@id='SubmitForm']/div[3]/a/div") # this is the image upload step        
        self.wait_for_page_to_load(1200)

        # to prove we have got back to the install_checklist page
        sel.click("link=Upload Images...")
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_13_create_floating_ips(self):
        sel = self.selenium
        sel.click("link=Create Floating IPs...")
        self.wait_for_page_to_load()
        # The floating ip range specified here belongs to network of OpenStack bangalore team.
        # This test just validates the Geppetto UI to create floating ips but doesn't validate the IPs.
        sel.type("id_command_line", "--ip_range=%s" % floating_ip_range)
        sel.click("//form[@id='SubmitForm']/div[3]/a/div")
        self.wait_for_page_to_load()
        # to prove we have got back to the install_checklist page
        sel.click("link=Create Floating IPs...")
        self.wait_for_page_to_load()

    def _configure_public_interface(self, node_index):
        sel = self.selenium
        # Goto Publish Service Wizard
        sel.click("link=Publish Service Wizard")
        self.wait_for_page_to_load()
        sel.select("id=id_worker", "index=%s" % node_index)
        sel.type("id=id_host_network", public_network_bridge)
        # We choose DHCP for public network because, we don't know
        # the public network configuration for jenkins' test servers
        sel.click("id=id_network_type_0")
        # Test infrastructure uses eth2 as public interface
        # eth3 is designated as guest networking interface
        sel.select("id=id_device", "label=eth2")
        self._click_next()
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    @common.conditional_skip()
    def test_14_setup_public_interface(self):
        if networking_mode != 'flat':
            for node_index in range(4):
                self._configure_public_interface(node_index + 1)


if __name__ == "__main__":
    selenium_url = sys.argv[1]
    selenium_port = sys.argv[2]
    common.screenshot_dir = sys.argv[3]
    xs_root_password = sys.argv[4]
    guest_network = sys.argv[5]
    dashboard_node_index = sys.argv[6]
    networking_mode = sys.argv[7]
    guest_network_bridge = sys.argv[8]
    public_network_bridge = sys.argv[9]
    floating_ip_range = sys.argv[10]
    skip_list = None
    if len(sys.argv) > 11:
        skip_list_str = sys.argv[11]
        skip_list = skip_list_str.split(',')
    # Ignore command line arguments
    unittest.main(argv=[sys.argv[0]])
