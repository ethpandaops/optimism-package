_input_parser = import_module("/src/mev/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(network_id=1000, network_name="my-l2")
_default_registry = _registry.Registry()


def test_mev_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in mev configuration for my-l2: extra,name",
    )


def test_mev_input_parser_default_args(plan):
    _default_params = struct(
        image="flashbots/rollup-boost:latest",
        type="rollup-boost",
        builder_host=None,
        builder_port=None,
        service_name="op-mev-rollup-boost-1000-my-l2",
        labels={
            "op.kind": "mev",
            "op.network.id": 1000,
            "op.mev.type": "rollup-boost",
        },
        ports={
            _net.RPC_PORT_NAME: _net.port(number=8541),
        },
    )

    expect.eq(
        _input_parser.parse(
            None,
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            {},
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            {
                "image": None,
                "type": None,
                "builder_host": None,
                "builder_port": None,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_mev_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        {
            "image": "op-rollup-boost:brightest",
            "builder_host": "localhost",
            "builder_port": 8080,
        },
        _default_network_params,
        _default_registry,
    )

    expect.eq(
        parsed,
        struct(
            image="op-rollup-boost:brightest",
            type="rollup-boost",
            builder_host="localhost",
            builder_port=8080,
            service_name="op-mev-rollup-boost-1000-my-l2",
            labels={
                "op.kind": "mev",
                "op.network.id": 1000,
                "op.mev.type": "rollup-boost",
            },
            ports={
                _net.RPC_PORT_NAME: _net.port(number=8541),
            },
        ),
    )


def test_mev_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.ROLLUP_BOOST: "rollup-boost:greatest"})

    parsed = _input_parser.parse(
        {},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "rollup-boost:greatest")

    parsed = _input_parser.parse(
        {"image": "rollup-boost:oldest"},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "rollup-boost:oldest")
