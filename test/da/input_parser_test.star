_input_parser = import_module("/src/da/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_da_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in DA configuration for my-l2: extra,name",
    )


def test_da_input_parser_default_args(plan):
    expect.eq(
        _input_parser.parse(
            None,
            _default_network_params,
            _default_registry,
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
                "enabled": False,
                "image": None,
                "cmd": None,
            },
            _default_network_params,
            _default_registry,
        ),
        None,
    )


def test_da_input_parser_enabled_default_args(plan):
    _default_params = struct(
        enabled=True,
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/da-server:latest",
        cmd=[
            "da-server",
            "--file.path=/home",
            "--addr=0.0.0.0",
            "--port={}".format(3100),
            "--log.level=debug",
        ],
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=3100),
        },
        service_name="op-da-da-server-1000-my-l2",
        labels={
            "op.kind": "da",
            "op.network.id": "1000",
            "op.da.type": "da-server",
        },
    )

    expect.eq(
        _input_parser.parse(
            {
                "enabled": True,
            },
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
                "cmd": None,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_da_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        {
            "enabled": True,
            "image": "op-da-server:brightest",
            "cmd": ["echo"],
        },
        _default_network_params,
        _default_registry,
    )

    expect.eq(
        parsed,
        struct(
            enabled=True,
            cmd=["echo"],
            image="op-da-server:brightest",
            ports={
                _net.HTTP_PORT_NAME: _net.port(number=3100),
            },
            service_name="op-da-da-server-1000-my-l2",
            labels={
                "op.kind": "da",
                "op.network.id": "1000",
                "op.da.type": "da-server",
            },
        ),
    )


def test_da_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.DA_SERVER: "op-da-server:greatest"})

    parsed = _input_parser.parse(
        {"enabled": True},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "op-da-server:greatest")

    parsed = _input_parser.parse(
        {"enabled": True, "image": "op-da-server:oldest"},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "op-da-server:oldest")
