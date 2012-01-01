#!/usr/bin/env python

import unittest
import time
import sys
import common

selenium_url = "http://localhost:8080/"
selenium_port = 4444

class GeppettoTestCase(common.SeleniumTestCase):
    # TODO Share this code with other tests
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
        sel.type("username", "root")
        sel.type("password", "citrix")
        sel.click("//form[@id='SubmitForm']/div[4]/a/div/div[1]")
        self.wait_for_page_to_load()

    @common.retry(Exception, tries=4)
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
    # END of TODO

    def _migrate_test(self, worker_type):
        sel = self.selenium

        sel.click("link=Upgrade Node...")
        self.wait_for_page_to_load()

        sel.select("id_openstack_worker", "label=%s" % worker_type)
        self._click_next()
        self.wait_for_page_to_load()

        sel.select("id=id_old_vpx", "index=1")
        sel.select("id=id_new_vpx", "index=1")
        self._click_next()
        self.wait_for_page_to_load()

        self._click_next()
        self.wait_for_page_to_load()
        self._check_back_at_install_checklist()

    @common.snapshot_on_error
    def test_010_migrate_compute(self):
        self._migrate_test("OpenStack Compute Worker")

    @common.snapshot_on_error
    def test_020_migrate_scheduler(self):
        self._migrate_test("OpenStack Compute Scheduler")

    @common.snapshot_on_error
    def test_030_migrate_image_api(self):
        self._migrate_test("OpenStack Image API")

    @common.snapshot_on_error
    def test_040_wait_till_setup_stable(self):
        sel = self.selenium
        sel.click("link=List Nodes...")
        self.wait_for_page_to_load()

        retry_count = 0
        max_retries = 20
        sleep_seconds = 30

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

if __name__ == "__main__":
    selenium_url = sys.argv[1]
    selenium_port = sys.argv[2]
    common.screenshot_dir = sys.argv[3]
    # Ignore command line arguments
    unittest.main(argv=[sys.argv[0]])
