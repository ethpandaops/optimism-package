_input_parser = import_module("/src/blockscout/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_blockscout_input_parser_extra_attrbutes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in blockscout configuration for my-l2: extra,name",
    )


def test_blockscout_input_parser_default_args_disabled(plan):
    expect.eq(
        _input_parser.parse(
            blockscout_args=None,
            network_params=_default_network_params,
            registry=_default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            {},
            _default_network_params,
            _default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            {
                "image": None,
                "verifier_image": None,
            },
            _default_network_params,
            _default_registry,
        ),
        None,
    )


def test_blockscout_input_parser_default_args_enabled(plan):
    _default_params = struct(
        blockscout=struct(
            image="blockscout/blockscout-optimism:6.8.0",
            labels={"op.kind": "blockscout", "op.network.id": "1000"},
            ports={_net.HTTP_PORT_NAME: _net.port(number=4000)},
            service_name="op-blockscout-1000-my-l2",
        ),
        database=struct(service_name="op-blockscout-db-1000-my-l2"),
        verifier=struct(
            image="ghcr.io/blockscout/smart-contract-verifier:v1.9.0",
            labels={"op.kind": "blockscout-verifier", "op.network.id": "1000"},
            ports={_net.HTTP_PORT_NAME: _net.port(number=8050)},
            service_name="op-blockscout-verifier-1000-my-l2",
        ),
    )

    expect.eq(
        _input_parser.parse(
            {"enabled": True},
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            {
                "enabled": True,
                "image": None,
                "verifier_image": None,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_blockscout_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        blockscout_args={
            "enabled": True,
            "image": "op-blockscout:brightest",
            "verifier_image": "op-blockscout-verifier:smallest",
        },
        network_params=_default_network_params,
        registry=_default_registry,
    )

    expect.eq(
        parsed.blockscout.image,
        "op-blockscout:brightest",
    )

    expect.eq(
        parsed.verifier.image,
        "op-blockscout-verifier:smallest",
    )


def test_blockscout_input_parser_custom_registry(plan):
    registry = _registry.Registry(
        {
            _registry.OP_BLOCKSCOUT: "op-blockscout:greatest",
            _registry.OP_BLOCKSCOUT_VERIFIER: "op-blockscout-verifier:shadiest",
        }
    )

    parsed = _input_parser.parse(
        blockscout_args={"enabled": True},
        network_params=_default_network_params,
        registry=registry,
    )
    expect.eq(parsed.blockscout.image, "op-blockscout:greatest")
    expect.eq(parsed.verifier.image, "op-blockscout-verifier:shadiest")

    parsed = _input_parser.parse(
        {
            "enabled": True,
            "image": "op-blockscout:oldest",
            "verifier_image": "op-blockscout-verifier:tiniest",
        },
        _default_network_params,
        registry,
    )
    expect.eq(parsed.blockscout.image, "op-blockscout:oldest")
    expect.eq(parsed.verifier.image, "op-blockscout-verifier:tiniest")
