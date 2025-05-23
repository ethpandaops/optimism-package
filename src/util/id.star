# IDs cannot contain '-' as we use '-' to separate elements in naming conventions
def assert_id(id):
    if "-" in id:
        fail("ID cannot contain '-': {}".format(id))


# Returns a autoincrementing ID generator function whose first value will be the `initial` argument
def autoincrement(initial=1):
    # Starlark does not seem to support mutable variables so we store the couter as the first element of a list
    bucket = [initial]

    def next():
        id = bucket[0]
        bucket[0] += 1

        return id

    return next
