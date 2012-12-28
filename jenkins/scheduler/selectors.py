def first(condition=lambda x: True):
    accumulator = []

    def term_generator(item):
        if len(accumulator) == 0 and condition(item):
            accumulator.append(item)
            return lambda: True
        return lambda: False

    return term_generator


def first_pair_where_vlans_match():
    """
    >>> database = []
    >>> tgen = first_pair_where_vlans_match()
    >>> callables = [tgen(i) for i in database]
    >>> [i() for i in callables]
    []
    >>> database = [dict(VLAN=1), dict(VLAN=2)]
    >>> tgen = first_pair_where_vlans_match()
    >>> callables = [tgen(i) for i in database]
    >>> [i() for i in callables]
    [False, False]
    >>> database = [dict(VLAN=1), dict(VLAN=2), dict(VLAN=2)]
    >>> tgen = first_pair_where_vlans_match()
    >>> callables = [tgen(i) for i in database]
    >>> [i() for i in callables]
    [False, True, True]
    >>> database = [dict(VLAN=1)]
    >>> tgen = first_pair_where_vlans_match()
    >>> callables = [tgen(i) for i in database]
    >>> [i() for i in callables]
    [False]
    """
    accumulator = []

    def get_indexes_of_first_pair():
        servers_by_vlans = dict()
        for idx, server in enumerate(accumulator):
            try:
                my_vlan = server['VLAN']
                if my_vlan in servers_by_vlans:
                    return [idx, servers_by_vlans[my_vlan]]
                servers_by_vlans[my_vlan] = idx
            except:
                pass
        return []

    def term_generator(item):
        item_index = len(accumulator)
        accumulator.append(item)
        return lambda: item_index in get_indexes_of_first_pair()

    return term_generator
