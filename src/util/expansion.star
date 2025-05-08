# Expands a field that can either be a list of values or a special "*" character into a list of values
#
# In case of "*", all_values value are returned.
# In case of a list, thus function will fail if any of the values are not in all_values
#
# Examples:
#
# expand_artifact("*", [1, 2]) == [1, 2]
# expand_artifact([1], [1, 2]) == [1]
# expand_artifact([3], [1, 2]) fails, 3 is not in [1, 2]
def expand_asterisc(
    value,
    all_values,
    missing_value_message="value {0} not allowed. allowed values are: {1}",
    wrong_type_message="value should be of type list. got {0} instead",
):
    # Asterics means all the values
    if value == "*":
        return all_values

    # Now we need to make sure we got a list of values
    if type(value) != "list":
        fail(wrong_type_message.format(value))

    # And we need to check that the values are a subset of all possible values
    return [
        e if e in all_values else fail(missing_value_message.format(e, all_values))
        for e in value
    ]
