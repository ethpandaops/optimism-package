expansion = import_module("/src/util/expansion.star")


def test_expansion_expand_asterisc(plan):
    expect.eq(expansion.expand_asterisc("*", []), [])
    expect.eq(expansion.expand_asterisc("*", [1, "hey"]), [1, "hey"])

    expect.fails(
        lambda: expansion.expand_asterisc([1, 2], [1, 10]),
        "value 2 not allowed. allowed values are: \\[1, 10\\]",
    )
    expect.fails(
        lambda: expansion.expand_asterisc({}, [1, 10]),
        "value should be of type list. got \\{\\} instead",
    )


def test_expansion_expand_asterisc_custom_error_messages(plan):
    expect.fails(
        lambda: expansion.expand_asterisc(
            [2], [1, 10], missing_value_message="{1} does not contain {0}"
        ),
        "\\[1, 10\\] does not contain 2",
    )
    expect.fails(
        lambda: expansion.expand_asterisc(
            False, [1, 10], wrong_type_message="value {} is no good"
        ),
        "value False is no good",
    )
