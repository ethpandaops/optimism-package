input_parser = import_module("/src/interop/input_parser.star")

_chains = [
    {"network_params": {"network_id": 1000}},
    {"network_params": {"network_id": 2000}},
]


def test_superchain_input_parser_empty(plan):
    expect.eq(
        input_parser.parse(
            None,
            _chains,
        ),
        [],
    )
    expect.eq(
        input_parser.parse(
            {},
            _chains,
        ),
        [],
    )


def test_superchain_input_parser_no_participants(plan):
    expect.eq(
        input_parser.parse(
            {"superchain-0": {"participants": []}},
            _chains,
        ),
        [],
    )


def test_superchain_input_parser_disabled(plan):
    expect.eq(
        input_parser.parse(
            {"superchain-0": {"enabled": False}},
            _chains,
        ),
        [],
    )


def test_superchain_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"superchain-0": {"name": "x", "extra": None}},
        ),
        "Invalid attributes in superchain configuration for superchain-0: extra,name",
    )


def test_superchain_input_parser_default_args(plan):
    expected_params = struct(
        enabled=True,
        name="superchain-0",
        participants=[1000, 2000],
    )

    expect.eq(
        input_parser.parse(
            {"superchain-0": None},
            _chains,
        ),
        [expected_params],
    )
    expect.eq(
        input_parser.parse(
            {"superchain-0": {}},
            _chains,
        ),
        [expected_params],
    )
    expect.eq(
        input_parser.parse(
            {"superchain-0": {"enabled": None, "participants": None}},
            _chains,
        ),
        [expected_params],
    )
