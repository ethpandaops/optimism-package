input_parser = import_module("/src/proposer/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_proposer_input_parser_extra_attrbutes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        " Invalid attributes in proposer configuration for my-l2: extra,name",
    )


def test_proposer_input_parser_default_args(plan):
    _default_params = struct(
        extra_params=[],
        game_type=1,
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:v1.10.0",
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8560),
        },
        proposal_interval="10m",
        service_name="op-proposer-1000-my-l2",
        labels={
            "op.kind": "proposer",
            "op.network.id": "1000",
        },
    )

    expect.eq(
        input_parser.parse(
            None,
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        input_parser.parse(
            {},
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        input_parser.parse(
            {
                "image": None,
                "extra_params": None,
                "game_type": None,
                "proposal_interval": None,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_proposer_input_parser_custom_params(plan):
    parsed = input_parser.parse(
        {
            "image": "op-proposer:brightest",
            "extra_params": ["--hola"],
            "game_type": 7,
            "proposal_interval": "3h",
        },
        _default_network_params,
        _default_registry,
    )

    expect.eq(
        parsed,
        struct(
            extra_params=["--hola"],
            game_type=7,
            image="op-proposer:brightest",
            ports={
                _net.HTTP_PORT_NAME: _net.port(number=8560),
            },
            proposal_interval="3h",
            service_name="op-proposer-1000-my-l2",
            labels={
                "op.kind": "proposer",
                "op.network.id": "1000",
            },
        ),
    )


def test_proposer_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.OP_PROPOSER: "op-proposer:greatest"})

    parsed = input_parser.parse(
        {},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "op-proposer:greatest")

    parsed = input_parser.parse(
        {"image": "op-proposer:oldest"},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "op-proposer:oldest")
