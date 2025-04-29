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


def matches_asterisc(value, values_or_asterisc):
    if values_or_asterisc == "*":
        return True
    else:
        return value in values_or_asterisc
