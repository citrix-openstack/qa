import database
import time
import random
import string
from selectors import first


def wait_for(selector_factory):
    lock = ''.join(random.choice(string.ascii_uppercase + string.digits) for x in range(16))

    while True:
        items = database.lock_items('server.database', lock, selector_factory())
        if items:
            break
        time.sleep(1)

    return items, lock


def wait_for_first(condition):
    selector_factory = lambda: first(condition)

    items, lock = wait_for(selector_factory)

    assert len(items) == 1

    return items[0], lock
