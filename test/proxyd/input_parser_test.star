_input_parser = import_module("/src/proxyd/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_participants_params = [
    struct(
        el=struct(
            name := "node0",
            service_name="op-el-node0",
            ports={_net.RPC_PORT_NAME: _net.port(number=8888)},
        )
    )
]
_default_registry = _registry.Registry()


def test_proxyd_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            proxyd_args={"extra": None, "name": "x"},
            network_params=_default_network_params,
            participants_params=_default_participants_params,
            registry=_default_registry,
        ),
        "Invalid attributes in proxyd configuration for my-l2: extra,name",
    )


def test_proxyd_input_parser_default_args(plan):
    _default_params = struct(
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd:v4.14.5",
        extra_params=[],
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8080),
        },
        service_name="proxyd-1000-my-l2",
        labels={
            "op.kind": "proxyd",
            "op.network.id": "1000",
        },
        replicas={"node0": "http://op-el-node0:8888"},
    )

    expect.eq(
        _input_parser.parse(
            proxyd_args=None,
            network_params=_default_network_params,
            participants_params=_default_participants_params,
            registry=_default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            proxyd_args={},
            network_params=_default_network_params,
            participants_params=_default_participants_params,
            registry=_default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            proxyd_args={
                "image": None,
                "extra_params": None,
            },
            network_params=_default_network_params,
            participants_params=_default_participants_params,
            registry=_default_registry,
        ),
        _default_params,
    )


def test_proxyd_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        proxyd_args={
            "image": "proxyd:brightest",
            "extra_params": ["--hola"],
        },
        network_params=_default_network_params,
        participants_params=_default_participants_params,
        registry=_default_registry,
    )

    expect.eq(
        parsed,
        struct(
            extra_params=["--hola"],
            image="proxyd:brightest",
            ports={
                _net.HTTP_PORT_NAME: _net.port(number=8080),
            },
            service_name="proxyd-1000-my-l2",
            labels={
                "op.kind": "proxyd",
                "op.network.id": "1000",
            },
            replicas={"node0": "http://op-el-node0:8888"},
        ),
    )


def test_proxyd_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.PROXYD: "proxyd:greatest"})

    parsed = _input_parser.parse(
        proxyd_args={},
        network_params=_default_network_params,
        participants_params=_default_participants_params,
        registry=registry,
    )
    expect.eq(parsed.image, "proxyd:greatest")

    parsed = _input_parser.parse(
        proxyd_args={"image": "proxyd:oldest"},
        network_params=_default_network_params,
        participants_params=_default_participants_params,
        registry=registry,
    )
    expect.eq(parsed.image, "proxyd:oldest")
