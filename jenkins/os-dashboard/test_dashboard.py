#!/usr/bin/env python

import unittest
import time
import sys
import random

import common

selenium_url = "http://localhost:8080/"
selenium_port = 4444
usr_mail = "#openstack-commit@citrite.net"
img_id = 3
net_addr = "10.0.0."
key_pair_name = "dummy_name"


class OSDashboardTestCase(common.SeleniumTestCase):
    def setUp(self):
        self.set_up_selenium(selenium_url, selenium_port)
        self._login()

    def tearDown(self):
        self._logout()
        self.stop_selenium()

    @common.retry(Exception, tries=4)
    def _login(self):
        sel = self.selenium
        sel.open("/")
        self.wait_for_page_to_load()
        sel.type("id_username", "root")
        sel.type("id_password", "citrix")
        sel.click("home_login_btn")
        self.wait_for_page_to_load()

    @common.retry(Exception, tries=4)
    def _logout(self):
        sel = self.selenium
        sel.open("/")
        self.wait_for_page_to_load()
        sel.click("drop_btn")
        sel.click("link=Sign Out")
        self.wait_for_page_to_load()

    def _create_keypair(self):
        sel = self.selenium
        sel.click("link=Keypairs")
        self.wait_for_page_to_load()

        sel.click("id=keypairs_create_link")
        self.wait_for_page_to_load()

        sel.type("id_name", key_pair_name)
        sel.click("css=input.large-rounded")
        time.sleep(5)
        sel.click("link=<< Return to keypairs list")
        self.wait_for_page_to_load()

    def _allocate_floating_ip(self):
        sel = self.selenium
        sel.click("link=Floating IPs")
        self.wait_for_page_to_load()
        sel.click("css=input.action_input.large-rounded")
        time.sleep(3)
        self.wait_for_page_to_load()

    def _release_floating_ip(self):
        sel = self.selenium
        sel.click("link=Floating IPs")
        self.wait_for_page_to_load()
        sel.click("//input[@value='Release']")
        self.failUnless(sel.get_confirmation().startswith(
            "Are you sure you want to delete the Floating IP:"))
        self.wait_for_page_to_load()

    def _disassociate_floating_ip(self):
        sel = self.selenium
        sel.click("link=Floating IPs")
        self.wait_for_page_to_load()
        sel.click("//input[@value='Disassociate']")
        self.failUnless(sel.get_confirmation().startswith(
            "Are you sure you want to delete the Disassociate Floating IP:"))
        self.wait_for_page_to_load()

    def _associate_floating_ip(self):
        sel = self.selenium
        sel.click("link=Floating IPs")
        self.wait_for_page_to_load()
        sel.click("link=Associate to instance")
        self.wait_for_page_to_load()
        sel.click("//input[@value='Associate IP']")
        time.sleep(5)
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    def test_1_create_keypair(self):
        sel = self.selenium
        self._create_keypair()
        # note Firefox must be confirmed so the pem fine
        # auto downloads and doesn't just cause this to time out
        try:
            self.failUnless(sel.is_text_present(key_pair_name))
        except AssertionError, e:
            self.verificationErrors.append(str(e))

    def _create_instance(self, image_id):
        sel = self.selenium
        sel.click("link=Images")
        self.wait_for_page_to_load()

        image_link = "launch_%s" % image_id
        try:
            self.failUnless(sel.is_element_present(image_link))
        except AssertionError, e:
            self.verificationErrors.append(str(e))
        sel.click(image_link)
        self.wait_for_page_to_load()

        sel.open("/dash/1234/images/")
        sel.click(image_link)
        self.wait_for_page_to_load()

        sel.type("id_name", "test_server")
        sel.select("id_key_name", "value=%s" % key_pair_name)
        sel.click("//input[@value='Launch Instance']")
        self.wait_for_page_to_load()

    @common.snapshot_on_error
    def test_2_create_instance(self):
        self._create_instance(img_id)
        try:
            self.failUnless(
                self.selenium.is_text_present(
                    "Instance was successfully launched"))
        except AssertionError, e:
            self.verificationErrors.append(str(e))
        self.wait_for_text("Build")
        self.wait_for_text("Active")
        self.wait_for_text(net_addr)

    @common.snapshot_on_error
    def test_3_allocate_floatingIP(self):
        sel = self.selenium
        if net_mode != "flat":
            self._allocate_floating_ip()
            try:
                self.failUnless(sel.is_text_present("Successfully allocated Floating IP"))
            except AssertionError, e:
                self.verificationErrors.append(str(e))

    @common.snapshot_on_error
    def test_4_associate_floatingIP(self):
        sel = self.selenium
        if net_mode != "flat":
            self._associate_floating_ip()
            try:
                self.failUnless(sel.is_text_present("Successfully associated Floating IP"))
            except AssertionError, e:
                self.verificationErrors.append(str(e))

    @common.snapshot_on_error
    def test_5_disassociate_floatingIP(self):
        sel = self.selenium
        if net_mode != "flat":
            self._disassociate_floating_ip()
            try:
                self.failUnless(sel.is_text_present("Successfully disassociated Floating IP"))
            except AssertionError, e:
                self.verificationErrors.append(str(e))

    @common.snapshot_on_error
    def test_6_release_floatingIP(self):
        sel = self.selenium
        if net_mode != "flat":
            self._release_floating_ip()
            try:
                self.failUnless(sel.is_text_present("Successfully released Floating IP"))
            except AssertionError, e:
                self.verificationErrors.append(str(e))


if __name__ == "__main__":
    selenium_url = sys.argv[1]
    selenium_port = sys.argv[2]
    common.screenshot_dir = sys.argv[3]
    usr_mail = sys.argv[4]
    img_id = sys.argv[5]
    net_addr = sys.argv[6]
    net_mode = sys.argv[7]

    #generate a random keypair name
    key_pair_name = "key_pair_%s" % random.randint(0, 100000)

    # Ignore command line arguments
    unittest.main(argv=[sys.argv[0]])
