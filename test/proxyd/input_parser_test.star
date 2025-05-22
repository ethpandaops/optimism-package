_input_parser = import_module("/src/proxyd/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_proxyd_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        " Invalid attributes in proxyd configuration for my-l2: extra,name",
    )


def test_proxyd_input_parser_default_args(plan):
    _default_params = struct(
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd:v4.14.2",
        extra_params=[],
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8080),
        },
        service_name="proxyd-1000-my-l2",
        labels={
            "op.kind": "proxyd",
            "op.network.id": 1000,
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
                "extra_params": None,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_proxyd_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        {
            "image": "proxyd:brightest",
            "extra_params": ["--hola"],
        },
        _default_network_params,
        _default_registry,
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
                "op.network.id": 1000,
            },
        ),
    )


def test_proxyd_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.PROXYD: "proxyd:greatest"})

    parsed = _input_parser.parse(
        {},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "proxyd:greatest")

    parsed = _input_parser.parse(
        {"image": "proxyd:oldest"},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "proxyd:oldest")
