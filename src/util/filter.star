# Removes all None values from a dictionary (list) returns a new dictionary (list).
def filter_none(p):
    p_type = type(p)
    if p_type == "list":
        return [v for v in p if v != None]
    elif p_type == "dict":
        return {k: v for k, v in p.items() if v != None}
    else:
        fail("Unsupported type for filter_none: {0}".format(p_type))