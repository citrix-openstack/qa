from selectors import first


def set_database(filename, contents):
    """
    >>> import os
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[]')
    >>> os.path.exists('test_db')
    True
    >>> if os.path.exists('test_db'): os.unlink('test_db')
    >>> set_database('test_db', '[1, 2, 3]')
    >>> os.path.exists('test_db')
    True
    """

    import sqlite3
    conn = sqlite3.connect(filename)

    c = conn.cursor()

    c.execute('DROP TABLE IF EXISTS stuff')
    c.execute('CREATE TABLE stuff (id INTEGER PRIMARY KEY, data TEXT, lock TEXT)')

    id = 0
    for record in eval(contents):
        c.execute('INSERT INTO stuff (id, data, lock) VALUES(:id, :data, :lock)',
            dict(id=id, data=repr(record), lock=""))
        id += 1

    conn.commit()
    conn.close()


def get_database(filename):
    """
    >>> set_database('test_db', '["a", "b", "c"]')
    >>> get_database('test_db')
    ['a', 'b', 'c']
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


def lock_items(filename, lock, term_generator=None):
    """
    >>> set_database('test_db', '[1, 2, 3]')
    >>> lock_items('test_db', 'a')
    [1]
    >>> lock_items('test_db', 'b')
    [2]
    >>> lock_items('test_db', '')
    Traceback (most recent call last):
    ...
    ValueError: Invalid lock value: ''
    >>> set_database('test_db', '[]')
    >>> lock_items('test_db', 'c')
    []
    >>> set_database('test_db', '[1, 2, 3]')
    >>> seen_items = []
    >>> lock_items('test_db', 'a', lambda x: lambda: seen_items.append(x))
    []
    >>> seen_items
    [1, 2, 3]
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

    conn.commit()
    conn.close()

    return results


def get_locks(filename):
    """
    >>> set_database('test_db', '[1, 2, 3]')
    >>> get_locks('test_db')
    []
    >>> lock_items('test_db', 'lock1')
    [1]
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


def release_lock(filename, lock):
    """
    >>> set_database('test_db', '[1, 2, 3]')
    >>> release_lock('test_db', 'somelock')
    >>> lock_items('test_db', 'lock1')
    [1]
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
