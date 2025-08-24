_input_parser = import_module("/src/flashblocks/input_parser.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_flashblocks_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in flashblocks websocket proxy configuration for network my-l2",
    )


def test_flashblocks_input_parser_default_args(plan):
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
            {"enabled": False},
            _default_network_params,
            _default_registry,
        ),
        None,
    )


def test_flashblocks_input_parser_enabled_default_args(plan):
    _default_params = struct(
        enabled=True,
        image="us-docker.pkg.dev/oplabs-tools-artifacts/dev-images/flashblocks-websocket-proxy:v1.0.0",
        global_connections_limit=100,
        log_format="text",
        log_level="info",
        message_buffer_size=20,
        per_ip_connections_limit=10,
        service_name="flashblocks-websocket-proxy-1000-my-l2",
        labels={
            "op.kind": "flashblocks-websocket-proxy",
            "op.network.id": "1000",
            "op.service.type": "websocket-proxy",
        },
        ports={
            _net.WS_PORT_NAME: _net.port(number=8545, application_protocol="ws"),
        },
    )

    expect.eq(
        _input_parser.parse(
            {"enabled": True},
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_flashblocks_input_parser_custom_params(plan):
    custom_params = struct(
        enabled=True,
        image="custom-flashblocks:latest",
        global_connections_limit=200,
        log_level="debug",
        message_buffer_size=50,
    )

    parsed = _input_parser.parse(
        {
            "enabled": True,
            "image": "custom-flashblocks:latest",
            "global_connections_limit": 200,
            "log_level": "debug",
            "message_buffer_size": 50,
        },
        _default_network_params,
        _default_registry,
    )

    expect.eq(parsed.enabled, True)
    expect.eq(parsed.image, "custom-flashblocks:latest")
    expect.eq(parsed.global_connections_limit, 200)
    expect.eq(parsed.log_level, "debug")
    expect.eq(parsed.message_buffer_size, 50)
    expect.eq(parsed.log_format, "text")
    expect.eq(parsed.per_ip_connections_limit, 10)
