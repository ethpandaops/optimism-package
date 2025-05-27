_sequence = import_module("/src/util/sequence.star")


def test_sequence_autoincrement_default_initial_value(plan):
    id = _sequence.autoincrement()

    expect.eq(id(), 1)
    expect.eq(id(), 2)
    expect.eq(id(), 3)
    expect.eq(id(), 4)


def test_sequence_autoincrement_custom_initial_value(plan):
    id = _sequence.autoincrement(1000)

    expect.eq(id(), 1000)
    expect.eq(id(), 1001)
    expect.eq(id(), 1002)
    expect.eq(id(), 1003)
    expect.eq(id(), 1004)


def test_sequence_round_robin_nonempty_values(plan):
    id = _sequence.round_robin(["a", 1000, []])

    expect.eq(id(), "a")
    expect.eq(id(), 1000)
    expect.eq(id(), [])
    expect.eq(id(), "a")
    expect.eq(id(), 1000)
    expect.eq(id(), [])


def test_sequence_round_robin_empty_values_no_default(plan):
    id = _sequence.round_robin([])

    expect.eq(id(), None)
    expect.eq(id(), None)
    expect.eq(id(), None)


def test_sequence_round_robin_empty_values_default(plan):
    id = _sequence.round_robin([], "default")

    expect.eq(id(), "default")
    expect.eq(id(), "default")
    expect.eq(id(), "default")


def test_sequence_round_robin_skipped_values(plan):
    id = _sequence.round_robin(["a", 1000, []])

    # First we skip some values
    expect.eq(id(["a", []]), 1000)
    # Then we expect the sequence to continue from the last selected value
    expect.eq(id(), [])
    expect.eq(id(), "a")

    # And again we skip
    expect.eq(id([1000]), [])
    # And again we continue
    expect.eq(id(), "a")

    # If we skip everything we get the default value
    expect.eq(id(["a", 1000, []]), None)
    # Adn we expect to continue where we left off
    expect.eq(id(), 1000)


def test_sequence_round_robin_skipped_values_custom_default(plan):
    id = _sequence.round_robin(["a", 1000, []], default={})

    # If we skip everything, we get the custom default
    expect.eq(id(["a", 1000, []]), {})
