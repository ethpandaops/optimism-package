_id = import_module("/src/util/id.star")


def test_id_assert_id(plan):
    expect.fails(
        lambda: _id.assert_id(""), "ID cannot be empty or whitespace only, got ''"
    )
    expect.fails(
        lambda: _id.assert_id("   "), "ID cannot be empty or whitespace only, got '   '"
    )

    expect.fails(
        lambda: _id.assert_id("no_underscores"),
        "ID can only contain alphanumeric characters and '-', got 'no_underscores'",
    )
    expect.fails(
        lambda: _id.assert_id("no.periods"),
        "ID can only contain alphanumeric characters and '-', got 'no\\.periods'",
    )
    expect.fails(
        lambda: _id.assert_id("no,commas"),
        "ID can only contain alphanumeric characters and '-', got 'no,commas'",
    )
    expect.fails(
        lambda: _id.assert_id("no?weirdness"),
        "ID can only contain alphanumeric characters and '-', got 'no\\?weirdness'",
    )

    expect.fails(
        lambda: _id.assert_id(" ", "A name"),
        "A name cannot be empty or whitespace only, got ' '",
    )
    expect.fails(
        lambda: _id.assert_id("custom?name", "A name"),
        "A name can only contain alphanumeric characters and '-', got 'custom\\?name'",
    )

    expect.eq(_id.assert_id("-"), "-")
    expect.eq(_id.assert_id("abcd1234-"), "abcd1234-")


def test_id_autoincrement_default_initial_value(plan):
    id = _id.autoincrement()

    expect.eq(id(), 1)
    expect.eq(id(), 2)
    expect.eq(id(), 3)
    expect.eq(id(), 4)


def test_id_autoincrement_custom_initial_value(plan):
    id = _id.autoincrement(1000)

    expect.eq(id(), 1000)
    expect.eq(id(), 1001)
    expect.eq(id(), 1002)
    expect.eq(id(), 1003)
    expect.eq(id(), 1004)
