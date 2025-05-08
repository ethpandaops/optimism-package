# Removes all None values from a dictionary (or a list) returns a new dictionary (or a list).
def remove_none(p):
    p_type = type(p)
    if p_type == "list":
        return [v for v in p if v != None]
    elif p_type == "dict":
        return {k: v for k, v in p.items() if v != None}
    else:
        fail(
            "Unsupported type for remove_none: want list or dict, got {0}".format(
                p_type
            )
        )


# Removes all properties from a dictionary whose keys are not listed in the keys list
def remove_keys(p, keys):
    # Just a quick sanity check
    if type(keys) != "list":
        fail("Second argument to remove_keys must be a list, got {}".format(keys))

    p_type = type(p)
    if p_type == "dict":
        return {k: v for k, v in p.items() if k not in keys}
    else:
        fail("Unsupported type for remove_keys: want dict, got {0}".format(p_type))


# Fails with a message if a dictionary contains any keys that are not listed in the keys list
def assert_keys(p, keys, message="Invalid attributes specified: {}"):
    extra_keys = remove_keys(p, keys)

    if len(extra_keys) > 0:
        fail(message.format(",".join(extra_keys)))


# Returns the first element in a list that matches the predicate, or the default value if no element matches.
def first(p, predicate=lambda v: v, default=None):
    for item in p:
        if predicate(item):
            return item
    return default
