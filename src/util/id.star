# IDs cannot contain '-' as we use '-' to separate elements in naming conventions
def assert_id(id):
    if "-" in id:
        fail("ID cannot contain '-': {}".format(id))
