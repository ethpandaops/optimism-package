launcher = import_module("/src/flashblocks/flashblocks-websocket-proxy/launcher.star")
_net = import_module("/src/util/net.star")
_observability = import_module("/src/observability/observability.star")

_default_params = struct(
    service_name="flashblocks-websocket-proxy-1000-my-l2",
    image="flashblocks-websocket-proxy:latest",
    global_connections_limit=100,
    log_format="text",
    log_level="info",
    message_buffer_size=20,
    per_ip_connections_limit=10,
    labels={
        "op.kind": "flashblocks-websocket-proxy",
        "op.network.id": "1000",
        "op.service.type": "websocket-proxy",
    },
    ports={
        _net.WS_PORT_NAME: _net.port(number=8545, application_protocol="ws"),
    },
)

_default_conductors_params = [
    struct(
        service_name="op-conductor-1000-node0",
        ports={
            _net.WS_PORT_NAME: _net.port(number=8546, application_protocol="ws"),
        },
    ),
]

_default_observability_helper = _observability.make_helper(
    struct(enabled=True, metrics=struct(port=9001))
)


def test_flashblocks_websocket_proxy_launch_with_defaults(plan):
    result = launcher.launch(
        plan=plan,
        params=_default_params,
        conductors_params=_default_conductors_params,
        observability_helper=_default_observability_helper,
    )

    service_config = kurtosistest.get_service_config(_default_params.service_name)
    expect.ne(service_config, None)
    expect.eq(service_config.image, _default_params.image)
    expect.eq(service_config.labels, _default_params.labels)
    # Check that the service was created
    expect.ne(service_config, None)
    expect.eq(service_config.image, _default_params.image)
    expect.eq(service_config.labels, _default_params.labels)

    # Check that the WS port is configured
    expect.eq(service_config.ports["ws"].number, 8545)
    expect.eq(service_config.ports["ws"].application_protocol, "ws")

    # Check environment variables
    expect.eq(service_config.env_vars["GLOBAL_CONNECTIONS_LIMIT"], "100")
    expect.eq(service_config.env_vars["LISTEN_ADDR"], "0.0.0.0:8545")
    expect.eq(service_config.env_vars["LOG_FORMAT"], "text")
    expect.eq(service_config.env_vars["LOG_LEVEL"], "info")
    expect.eq(service_config.env_vars["MESSAGE_BUFFER_SIZE"], "20")
    expect.eq(service_config.env_vars["PER_IP_CONNECTIONS_LIMIT"], "10")
    expect.eq(
        service_config.env_vars["UPSTREAM_WS"], "ws://op-conductor-1000-node0:8546/ws"
    )
    expect.eq(service_config.env_vars["METRICS"], "true")
    expect.eq(service_config.env_vars["METRICS_ADDR"], "0.0.0.0:9001")
