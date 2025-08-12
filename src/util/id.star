# IDs, since they are being used in service names, can only contain alphanumeric characters and -
def assert_id(id, name="ID"):
    if not id.strip():
        fail("{} cannot be empty or whitespace only, got '{}'".format(name, id))

    # Unfortunately starlark does not support regular expressions so we'll have to do the check char by char
    allowed = "0123456789-abcdefghijklmnopqrstuvwxyz"

    for char in id.elems():
        if not char in allowed and not char.lower() in allowed:
            fail(
                "{} can only contain alphanumeric characters and '-', got '{}'".format(
                    name, id
                )
            )

    return id


# Returns a autoincrementing ID generator function whose first value will be the `initial` argument
def autoincrement(initial=1):
    # Starlark does not seem to support mutable variables so we store the couter as the first element of a list
    bucket = [initial]

    def next():
        id = bucket[0]
        bucket[0] += 1

        return id

    return next
