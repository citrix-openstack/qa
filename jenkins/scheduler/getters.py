import database
import time
import random
import string
from selectors import first


def wait_for_first(condition):
    lock = ''.join(random.choice(string.ascii_uppercase + string.digits) for x in range(16))

    while True:
        items = database.lock_items('server.database', lock, first(condition))
        if items:
            break
        time.sleep(1)

    return items[0], lock


