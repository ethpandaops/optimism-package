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


def test_filter_assert_keys(plan):
    filter.assert_keys({}, [])
    filter.assert_keys({}, ["key"])
    filter.assert_keys({"key": "value"}, ["key"])
    filter.assert_keys({"key": "value"}, ["key", "other"])

    expect.fails(
        lambda: filter.assert_keys({"key": True, "kee": None}, []),
        "Invalid attributes specified: key,kee",
    )
    expect.fails(
        lambda: filter.assert_keys({"kee": "value"}, ["key"]),
        "Invalid attributes specified: kee",
    )

    expect.fails(
        lambda: filter.assert_keys(
            {"key": False}, [], "Invalid attributes in my little object: {}"
        ),
        "Invalid attributes in my little object: key",
    )


def test_filter_first(plan):
    # With the default predicate
    expect.eq(filter.first([]), None)
    expect.eq(filter.first([None]), None)
    expect.eq(filter.first([False]), None)
    expect.eq(filter.first([[]]), None)

    # With custom predicate
    expect.eq(filter.first([1, 2, 3], lambda v: v == 2), 2)
    expect.eq(filter.first([4, 5, 6], lambda v: v == 2), None)
    expect.eq(filter.first([False], lambda v: v != None), False)
    expect.eq(filter.first([[]], lambda v: v != None), [])

    # With custom default
    expect.eq(filter.first([False], default=4), 4)
