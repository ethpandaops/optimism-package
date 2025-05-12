input_parser = import_module("/src/superchain/input_parser.star")

_net = import_module("/src/util/net.star")

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
            {"superchain0": {"participants": []}},
            _chains,
        ),
        [],
    )


def test_superchain_input_parser_disabled(plan):
    expect.eq(
        input_parser.parse(
            {"superchain0": {"enabled": False}},
            _chains,
        ),
        [],
    )


def test_superchain_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"superchain0": {"extra": None, "name": "x"}},
            _chains,
        ),
        "Invalid attributes in superchain configuration for superchain0: extra,name",
    )


def test_superchain_input_parser_default_args(plan):
    expected_params = struct(
        enabled=True,
        name="superchain0",
        participants=[1000, 2000],
        ports={
            "rpc-interop": _net.port(
                number=9645,
                application_protocol="ws",
            )
        },
        dependency_set=struct(
            name="superchain-depset-superchain0",
            path="superchain-depset-superchain0.json",
            value={
                "dependencies": {
                    "1000": {
                        "chainIndex": "1000",
                        "activationTime": 0,
                        "historyMinTime": 0,
                    },
                    "2000": {
                        "chainIndex": "2000",
                        "activationTime": 0,
                        "historyMinTime": 0,
                    },
                }
            },
        ),
    )

    expect.eq(
        input_parser.parse(
            {"superchain0": None},
            _chains,
        ),
        [expected_params],
    )
    expect.eq(
        input_parser.parse(
            {"superchain0": {}},
            _chains,
        ),
        [expected_params],
    )
    expect.eq(
        input_parser.parse(
            {"superchain0": {"enabled": None, "participants": None}},
            _chains,
        ),
        [expected_params],
    )
