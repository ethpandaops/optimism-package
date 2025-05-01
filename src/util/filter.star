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
