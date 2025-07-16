input_parser = import_module("/src/challenger/input_parser.star")

_default_l2s_params = [
    struct(network_params=struct(network_id=1000)),
    struct(network_params=struct(network_id=2000)),
]


def test_challenger_input_parser_empty(plan):
    expect.eq(input_parser.parse(None, _default_l2s_params), [])
    expect.eq(input_parser.parse({}, _default_l2s_params), [])


def test_challenger_input_parser_disabled(plan):
    expect.eq(
        input_parser.parse({"challenger": {"enabled": False}}, _default_l2s_params), []
    )


def test_challenger_input_parser_no_participants(plan):
    expect.eq(
        input_parser.parse({"challenger": {"participants": []}}, _default_l2s_params),
        [],
    )


def test_challenger_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"challenger": {"extra": [], "name": ""}}, _default_l2s_params
        ),
        "Invalid attributes in challenger configuration for challenger: extra,name",
    )


def test_challenger_input_parser_default_args(plan):
    expected_params = struct(
        name="challenger",
        service_name="op-challenger-challenger-1000-2000",
        enabled=True,
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-challenger:v1.5.1",
        labels={"op.kind": "challenger", "op.network.id": "1000-2000"},
        extra_params=[],
        participants=[1000, 2000],
        cannon_prestate_path="",
        cannon_prestates_url="https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon",
        cannon_trace_types=[],
        datadir="/data/op-challenger/op-challenger-data",
    )

    expect.eq(
        input_parser.parse({"challenger": None}, _default_l2s_params),
        [expected_params],
    )
    expect.eq(
        input_parser.parse({"challenger": {}}, _default_l2s_params),
        [expected_params],
    )
    expect.eq(
        input_parser.parse(
            {
                "challenger": {
                    "enabled": None,
                    "image": None,
                    "extra_params": None,
                    "participants": None,
                    "cannon_prestate_path": None,
                    "cannon_prestates_url": None,
                    "cannon_trace_types": None,
                }
            },
            _default_l2s_params,
        ),
        [expected_params],
    )
