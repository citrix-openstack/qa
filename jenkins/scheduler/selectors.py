def first(condition=lambda x: True):
    accumulator = []

    def term_generator(item):
        if len(accumulator) == 0 and condition(item):
            accumulator.append(item)
            return lambda: True
        return lambda: False

    return term_generator
