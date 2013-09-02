from selectors import first

def set_database(filename, contents):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[]')
    >>> os.path.exists('test_db')
    True
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[dict(HOST=\"a\"), dict(HOST=\"b\"), dict(HOST=\"c\")]')
    >>> os.path.exists('test_db')
    True
    >>> lock_items('test_db', 'lock1')
    [{'HOST': 'a'}]
    >>> set_database('test_db', '[dict(HOST=\"c\"), dict(HOST=\"b\"), dict(HOST=\"a\")]')
    >>> os.path.exists('test_db')
    True
    >>> get_database('test_db')
    [{'HOST': 'c'}, {'HOST': 'b'}, {'HOST': 'a'}]
    >>> get_locks('test_db')
    [u'lock1']
    """

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    cur_locks = {}
    for table_name, in c.execute('SELECT name FROM sqlite_master WHERE type=\'table\' AND name=\'stuff\''):
        if table_name == "stuff":
            for lock, data in c.execute('SELECT lock, data FROM stuff'):
                cur_locks[eval(data)['HOST']] = lock

    c.execute('DROP TABLE IF EXISTS stuff')
    c.execute('CREATE TABLE stuff (id INTEGER PRIMARY KEY, data TEXT, lock TEXT, lock_reason TEXT)')

    id = 0
    for record in eval(contents):
        new_lock = cur_locks.get(record['HOST'], "")
        c.execute('INSERT INTO stuff (id, data, lock) VALUES(:id, :data, :lock)',
            dict(id=id, data=repr(record), lock=new_lock))
        id += 1

    conn.commit()
    conn.close()


def get_database(filename):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[dict(HOST=\"1\"), dict(HOST=\"2\"), dict(HOST=\"3\")]')
    >>> get_database('test_db')
    [{'HOST': '1'}, {'HOST': '2'}, {'HOST': '3'}]
    >>> set_database('test_db', '[]')
    >>> get_database('test_db')
    []
    """

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    result = []
    for id, data in c.execute('SELECT id, data FROM stuff ORDER by id'):
        result.append(eval(data))

    conn.close()
    return result


def lock_items(filename, lock, term_generator=None, lock_reason=None):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[dict(HOST=\"1\"), dict(HOST=\"2\"), dict(HOST=\"3\")]')
    >>> lock_items('test_db', 'a')
    [{'HOST': '1'}]
    >>> lock_items('test_db', 'b')
    [{'HOST': '2'}]
    >>> lock_items('test_db', '')
    Traceback (most recent call last):
    ...
    ValueError: Invalid lock value: ''
    >>> set_database('test_db', '[]')
    >>> lock_items('test_db', 'c')
    []
    >>> set_database('test_db', '[dict(HOST=\"1\"), dict(HOST=\"2\"), dict(HOST=\"3\")]')
    >>> seen_items = []
    >>> lock_items('test_db', 'a', lambda x: lambda: seen_items.append(x))
    []
    >>> seen_items
    [{'HOST': '1'}, {'HOST': '2'}, {'HOST': '3'}]
    """

    if lock == "":
        raise ValueError("Invalid lock value: %s" % repr(lock))

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    term_generator = term_generator or first()

    terms_ids_items = []
    for id, data in c.execute('SELECT id, data FROM stuff WHERE lock = :empty_lock ORDER by id', dict(empty_lock="")).fetchall():
        item = eval(data)
        terms_ids_items.append((term_generator(item), id, item))

    results = []
    for term, id, item in terms_ids_items:
        if term():
            c.execute('UPDATE stuff SET lock = :lock WHERE id = :id', dict(lock=lock, id=id))
            assert c.rowcount == 1
            results.append(item)
            
            if lock_reason:
                c.execute('UPDATE stuff SET lock_reason = :lock_reason WHERE id = :id', dict(lock_reason=lock_reason, id=id))
                assert c.rowcount == 1

    conn.commit()
    conn.close()

    return results


def get_locks(filename):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[dict(HOST=\"1\"), dict(HOST=\"2\"), dict(HOST=\"3\")]')
    >>> get_locks('test_db')
    []
    >>> lock_items('test_db', 'lock1')
    [{'HOST': '1'}]
    >>> get_locks('test_db')
    [u'lock1']
    """

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    locks = []
    for lock, in c.execute('SELECT DISTINCT(lock) FROM stuff WHERE lock <> :empty_lock ORDER by lock', dict(empty_lock="")).fetchall():
        locks.append(lock)

    conn.close()

    return locks

def get_lock_details(filename, hostname=None):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[dict(HOST=\"1\"), dict(HOST=\"2\"), dict(HOST=\"3\")]')
    >>> get_lock_details('test_db')
    {}
    >>> lock_items('test_db', 'lock1', lock_reason='reason')
    [{'HOST': '1'}]
    >>> get_lock_details('test_db')
    {'1': {'lock': u'lock1', 'reason': u'reason'}}
    >>> get_lock_details('test_db', '2')
    {}
    >>> get_lock_details('test_db', '1')
    {'1': {'lock': u'lock1', 'reason': u'reason'}}
    """

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    locks = {}
    for lock, data, reason, in c.execute('SELECT lock, data, lock_reason FROM stuff WHERE lock <> :empty_lock ORDER by id',
                                 dict(empty_lock="")).fetchall():
        item = eval(data)
        if hostname is None or item['HOST'] == hostname:
            locks[item['HOST']] = {'lock':lock, 'reason':reason}

    conn.close()

    return locks


def release_lock(filename, lock):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[dict(HOST=\"1\"), dict(HOST=\"2\"), dict(HOST=\"3\")]')
    >>> release_lock('test_db', 'somelock')
    >>> lock_items('test_db', 'lock1')
    [{'HOST': '1'}]
    >>> get_locks('test_db')
    [u'lock1']
    >>> release_lock('test_db', 'lock1')
    >>> get_locks('test_db')
    []
    """

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    c.execute('UPDATE stuff SET lock = :empty_lock WHERE lock = :lock', dict(empty_lock="", lock=lock))
    conn.commit()
    conn.close()
