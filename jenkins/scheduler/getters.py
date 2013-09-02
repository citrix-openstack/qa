import database
import time
import random
import string
from selectors import first


def wait_for(selector_factory, reason):
    lock = ''.join(random.choice(string.ascii_uppercase + string.digits) for x in range(16))

    while True:
        items = database.lock_items('server.database', lock, selector_factory(), reason)
        if items:
            break
        time.sleep(1)

    return items, lock


def wait_for_first(condition, reason):
    selector_factory = lambda: first(condition)

    items, lock = wait_for(selector_factory, reason)

    assert len(items) == 1

    return items[0], lock
