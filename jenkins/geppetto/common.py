import re
import time
import unittest

from functools import wraps
from datetime import datetime
from selenium import selenium


global screenshot_dir
screenshot_dir = "/tmp"


def conditional_skip():
    """ Decorator for skipping a test according to preferences set by the
    user on the command line when the test run was launched
    """    
    def deco_conditional_skip(f):
        def f_conditional_skip(*args,**kwargs):
            testObject = args[0] # self in the test
            if hasattr(testObject, 'skip_list') and testObject.skip_list:
                match=re.match("^test_([0-9][0-9]).*$",testObject._testMethodName)
                if len(match.groups())>0:
                    idx = match.group(1)
                    if idx in testObject.skip_list:
                        testObject.skipTest("Skipped by user")
                        return
            return f(*args, **kwargs)
        return f_conditional_skip
        
    return deco_conditional_skip

def retry(ExceptionToCheck, tries=4, delay=3, backoff=2):
    """Retry decorator
    original from http://wiki.python.org/moin/PythonDecoratorLibrary#Retry
    """
    def deco_retry(f):
        def f_retry(*args, **kwargs):
            mtries, mdelay = tries, delay
            try_one_last_time = True
            while mtries > 1:
                try:
                    return f(*args, **kwargs)
                    try_one_last_time = False
                    break
                except ExceptionToCheck, e:
                    print "%s, Retrying in %d seconds..." % (str(e), mdelay)
                    time.sleep(mdelay)
                    mtries -= 1
                    mdelay *= backoff
            if try_one_last_time:
                return f(*args, **kwargs)
            return
        return f_retry # true decorator
    return deco_retry


class SeleniumTestCase(unittest.TestCase):

    @retry(Exception, tries=60)
    def set_up_selenium(self, selenium_url, selenium_port=4444):
        self.verificationErrors = []
        #self.selenium = selenium("localhost", selenium_port, "*chrome", selenium_url)
        self.selenium = selenium("localhost", selenium_port, "*firefox", selenium_url)
        self.selenium.start()

    def stop_selenium(self):
        self.selenium.stop()
        self.assertEqual([], self.verificationErrors)

    @retry(Exception, tries=12)
    def wait_for_page_to_load(self, seconds=20):
        self.selenium.wait_for_page_to_load(seconds * 1000)

    @retry(Exception, tries=12)
    def wait_for_text(self, status, iterations=30, secs=20):
        for _ in xrange(iterations):
            try:
                if self.selenium.is_text_present(status):
                    break
            except:
                pass
            time.sleep(secs)
            self.selenium.refresh()
            self.wait_for_page_to_load()
        else:
            self.fail("timed out waiting for the text: '%s'" % status)


def snapshot_on_error(test):
    @wraps(test)
    def inner(*args, **kwargs):
        try:
            test(*args, **kwargs)
        except:
            testObject = args[0] # self in the test
            timestamp = datetime.now().isoformat().replace(':', '')
            filename = "%s/screenshot_%s_%s.png" % (screenshot_dir, testObject.id(), timestamp)
            testObject.selenium.capture_screenshot(filename)
            kwargs = ''
            try:
                testObject.selenium.capture_entire_page_screenshot(filename, kwargs)
                print "Taken screenshot of error: '%s'" % filename
            except Exception:
                pass
            raise
    return inner

