#!/usr/bin/env python

import database
import time
import random
import string

lock = ''.join(random.choice(string.ascii_uppercase + string.digits) for x in range(16))

while True:
    items = database.lock_items('server.database', lock)
    if items:
        break
    time.sleep(1)

server_data, = items
for item in server_data.items():
    print '%s=%s' % item

print "LOCK=%s" % lock
