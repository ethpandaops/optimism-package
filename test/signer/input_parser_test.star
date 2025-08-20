_input_parser = import_module("/src/signer/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_signer_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            signer_args={"extra": None, "name": "x"},
            network_params=_default_network_params,
            registry=_default_registry,
        ),
        "Invalid attributes in signer configuration for my-l2: extra,name",
    )


def test_signer_input_parser_default_args(plan):
    expect.eq(
        _input_parser.parse(
            signer_args=None,
            network_params=_default_network_params,
            registry=_default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            signer_args={},
            network_params=_default_network_params,
            registry=_default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            signer_args={"enabled": True},
            network_params=_default_network_params,
            registry=_default_registry,
        ),
        struct(
            enabled=True,
            image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-signer:v1.5.0",
            service_name="signer-1000-my-l2",
            ports={_net.HTTP_PORT_NAME: _net.port(number=8545)},
            labels={
                "op.kind": "signer",
                "op.network.id": "1000",
            },
        ),
    )


def test_signer_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        signer_args={
            "enabled": True,
            "image": "signer:brightest",
        },
        network_params=_default_network_params,
        registry=_default_registry,
    )

    expect.eq(
        parsed,
        struct(
            enabled=True,
            image="signer:brightest",
            service_name="signer-1000-my-l2",
            ports={_net.HTTP_PORT_NAME: _net.port(number=8545)},
            labels={
                "op.kind": "signer",
                "op.network.id": "1000",
            },
        ),
    )


def test_signer_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.OP_SIGNER: "signer:greatest"})

    parsed = _input_parser.parse(
        signer_args={"enabled": True},
        network_params=_default_network_params,
        registry=registry,
    )
    expect.eq(parsed.image, "signer:greatest")

    parsed = _input_parser.parse(
        signer_args={"enabled": True, "image": "signer:oldest"},
        network_params=_default_network_params,
        registry=registry,
    )
    expect.eq(parsed.image, "signer:oldest")
