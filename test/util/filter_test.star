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
    expect.fails(lambda: filter.remove_none(1), "Unsupported type for remove_none: int")
    expect.fails(
        lambda: filter.remove_none(""), "Unsupported type for remove_none: string"
    )
    expect.fails(
        lambda: filter.remove_none(False), "Unsupported type for remove_none: bool"
    )
    expect.fails(
        lambda: filter.remove_none(struct()), "Unsupported type for remove_none: struct"
    )
    expect.fails(
        lambda: filter.remove_none(None), "Unsupported type for remove_none: NoneType"
    )
