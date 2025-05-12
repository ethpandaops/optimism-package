filter = import_module("/src/util/filter.star")


def test_filter_remove_none(plan):
    # Dictionaries
    expect.eq(filter.remove_none({}), {})
    expect.eq(filter.remove_none({"key": "value"}), {"key": "value"})
    expect.eq(filter.remove_none({"key": None}), {})
    expect.eq(filter.remove_none({"key": False}), {"key": False})
    expect.eq(filter.remove_none({"key": 0}), {"key": 0})
    expect.eq(filter.remove_none({"key": ""}), {"key": ""})
    expect.eq(filter.remove_none({"key": []}), {"key": []})
    expect.eq(filter.remove_none({"key": {}}), {"key": {}})

    # Lists
    expect.eq(filter.remove_none([]), [])
    expect.eq(filter.remove_none(["value"]), ["value"])
    expect.eq(filter.remove_none([None, None]), [])
    expect.eq(filter.remove_none([False]), [False])
    expect.eq(filter.remove_none([0]), [0])
    expect.eq(filter.remove_none([""]), [""])
    expect.eq(filter.remove_none([[]]), [[]])
    expect.eq(filter.remove_none([{}]), [{}])

    # Other values
    expect.fails(
        lambda: filter.remove_none(1),
        "Unsupported type for remove_none: want list or dict, got int",
    )
    expect.fails(
        lambda: filter.remove_none(""),
        "Unsupported type for remove_none: want list or dict, got string",
    )
    expect.fails(
        lambda: filter.remove_none(False),
        "Unsupported type for remove_none: want list or dict, got bool",
    )
    expect.fails(
        lambda: filter.remove_none(struct()),
        "Unsupported type for remove_none: want list or dict, got struct",
    )
    expect.fails(
        lambda: filter.remove_none(None),
        "Unsupported type for remove_none: want list or dict, got NoneType",
    )


def test_filter_remove_keys(plan):
    expect.eq(filter.remove_keys({}, ["k"]), {})
    expect.eq(filter.remove_keys({"k": 1, "l": 2}, ["k"]), {"l": 2})
    expect.eq(filter.remove_keys({"k": 1, "l": 2}, ["k", "l", "m"]), {})

    expect.fails(
        lambda: filter.remove_keys({}, {}),
        "Second argument to remove_keys must be a list, got \\{\\}",
    )

    expect.fails(
        lambda: filter.remove_keys({}, struct()),
        "Second argument to remove_keys must be a list, got struct\\(\\)",
    )

    expect.fails(
        lambda: filter.remove_keys(None, []),
        "Unsupported type for remove_keys: want dict, got NoneType",
    )
    expect.fails(
        lambda: filter.remove_keys(6, []),
        "Unsupported type for remove_keys: want dict, got int",
    )
    expect.fails(
        lambda: filter.remove_keys([], []),
        "Unsupported type for remove_keys: want dict, got list",
    )
