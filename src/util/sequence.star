# Returns a autoincrementing ID generator function whose first value will be the `initial` argument
def autoincrement(initial=1):
    # Starlark does not seem to support mutable variables so we store the couter as the first element of a list
    bucket = [initial]

    def next():
        id = bucket[0]
        bucket[0] += 1

        return id

    return next


def round_robin(values, default=None):
    n = len(values)

    # Starlark does not seem to support mutable variables so we store the couter as the first element of a list
    bucket = [0]

    def next(skipped_values=[]):
        # If we want to skip any values, we can pass a list of these
        values_without_skipped = [v for v in values if v not in skipped_values]

        # If we don't have any values left when skipping, we return the default
        n_without_skipped = len(values_without_skipped)
        if n_without_skipped == 0:
            return default

        # At this point we know that we have at least one value that is not being skipped
        #
        # That means that we have a guarantee that if we cycle through all the values,
        # we are going to find one that's not skipped
        for i in range(n):
            value = values[bucket[0]]

            bucket[0] += 1
            bucket[0] %= n

            if value not in skipped_values:
                return value

        # We add this statement just as an extra measure in case our logic above was flawed
        fail("invariant error: round_robin did not find the next value")

    return next
