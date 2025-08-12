input_parser = import_module("/src/test-sequencer/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_test_sequencer = struct(
    extra_params=[],
    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-test-sequencer:develop",
    name="test-sequencer",
    ports={
        "rpc": _net.port(
            number=8545,
        )
    },
    service_name="op-test-sequencer-sequencer",
)

_default_registry = _registry.Registry()


def test_test_sequencer_input_parser_empty(plan):
    expect.eq(
        input_parser.parse(None, _default_registry),
        [],
    )
    expect.eq(
        input_parser.parse({}, _default_registry),
        [],
    )


def test_test_sequencer_input_parser_extra_attrbutes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"sequencer": {"extra": None, "name": "x"}},
            _default_registry,
        ),
        "Invalid attributes in test sequencer configuration for sequencer: extra,name",
    )


def test_test_sequencer_input_parser_default_args(plan):
    expect.eq(
        input_parser.parse(
            {
                "sequencer0": {
                    "enabled": None,
                    "image": None,
                    "extra_params": None,
                }
            },
            _default_registry,
        ),
        [
            struct(
                enabled=True,
                extra_params=[],
                image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-test-sequencer:develop",
                labels={
                    "op.kind": "test-sequencer",
                },
                name="sequencer0",
                ports={
                    "rpc": _net.port(
                        number=8545,
                    )
                },
                service_name="op-test-sequencer-sequencer0",
                pprof_enabled=False,
            ),
        ],
    )


def test_test_sequencer_input_parser_custom_params(plan):
    parsed = input_parser.parse(
        {
            "sequencer0": {
                "image": "op-test-sequencer:lastest",
                "extra_params": ["--hey"],
            },
        },
        _default_registry,
    )

    expect.eq(parsed[0].image, "op-test-sequencer:lastest")
    expect.eq(parsed[0].extra_params, ["--hey"])


def test_test_sequencer_input_parser_custom_registry(plan):
    registry = _registry.Registry(
        {_registry.OP_TEST_SEQUENCER: "op-test-sequencer:latest"}
    )

    parsed = input_parser.parse(
        {
            "sequencer0": {},
        },
        registry,
    )
    expect.eq(parsed[0].image, "op-test-sequencer:latest")

    parsed = input_parser.parse(
        {
            "sequencer0": {
                "image": "op-test-sequencer:oldest",
            },
        },
        registry,
    )
    expect.eq(parsed[0].image, "op-test-sequencer:oldest")
