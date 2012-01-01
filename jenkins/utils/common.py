import csv
import sys
import time


RETRIES = 210
TIMEOUT = 10


def retry(f, m):
    """Retry f multiple times. Shows message m."""
    retries = 0
    fail = None
    while True:
        try:
            result = f()
            print >> sys.stderr, \
                "%(m)s: success after %(retries)d retries." % locals()
            return result
        except Exception, exn:
            print >> sys.stderr, exn
            time.sleep(TIMEOUT)
            fail = exn
        retries += 1
        if retries == RETRIES:
            print >> sys.stderr, \
                "%(m)s: failed after %(retries)d retries." % locals()
            raise fail


def parse(s):
    """Parse a comma-separated list of key=value pairs into a dictionary."""
    return dict(csv.reader([item],
                           delimiter='=',
                           quotechar="'").next()
                for item in csv.reader([s],
                                       delimiter=',',
                                       quotechar="'").next())
