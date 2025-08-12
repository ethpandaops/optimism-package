flashblocks_websocket_proxy_launcher = import_module(
    "/src/flashblocks/flashblocks-websocket-proxy/launcher.star"
)
_registry = import_module("/src/package_io/registry.star")
_net = import_module("/src/util/net.star")

_default_registry = _registry.Registry()


def test_flashblocks_websocket_proxy_get_service_config_basic(plan):
    """Test basic service config generation for flashblocks websocket proxy"""

    # Mock parameters
    params = struct(
        image="test/flashblocks-proxy:latest",
        ports={
            "ws": _net.port(number=8545, transport_protocol="TCP"),
            "metrics": _net.port(number=9000, transport_protocol="TCP"),
        },
        labels={"app": "flashblocks-proxy"},
    )

    # Mock network params
    network_params = struct(network_id="2151908", name="test-network")

    # Mock conductor contexts (empty list to start)
    conductors_contexts = []

    # Mock observability helper
    observability_helper = struct(enabled=False)

    config = flashblocks_websocket_proxy_launcher.get_service_config(
        plan=plan,
        params=params,
        conductors_contexts=conductors_contexts,
        observability_helper=observability_helper,
    )

    # Verify basic configuration
    expect.eq(config.image, "test/flashblocks-proxy:latest")
    expect.eq(len(config.ports), 2)
    expect.eq(config.labels, {"app": "flashblocks-proxy"})

    # Verify environment variables with empty upstream
    expect.eq(config.env_vars["GLOBAL_CONNECTIONS_LIMIT"], "100")
    expect.eq(config.env_vars["LISTEN_ADDR"], "0.0.0.0:8545")
    expect.eq(config.env_vars["LOG_LEVEL"], "info")
    expect.eq(config.env_vars["METRICS"], "true")
    expect.eq(config.env_vars["UPSTREAM_WS"], "")  # Empty when no conductors


def test_flashblocks_websocket_proxy_get_service_config_with_conductors(plan):
    """Test service config generation with conductor contexts"""

    # Mock parameters
    params = struct(
        image="test/flashblocks-proxy:latest",
        ports={
            "ws": _net.port(number=8545, transport_protocol="TCP"),
            "metrics": _net.port(number=9000, transport_protocol="TCP"),
        },
        labels={},
    )

    # Mock conductor contexts
    conductor1 = struct(
        service_name="conductor-1-test-network", conductor_rpc_port=8547
    )
    conductor2 = struct(
        service_name="conductor-2-test-network", conductor_rpc_port=8547
    )
    conductors_contexts = [conductor1, conductor2]

    # Mock observability helper
    observability_helper = struct(enabled=False)

    config = flashblocks_websocket_proxy_launcher.get_service_config(
        plan=plan,
        params=params,
        conductors_contexts=conductors_contexts,
        observability_helper=observability_helper,
    )

    # Verify upstream URLs are generated correctly
    expected_upstream = (
        "ws://conductor-1-test-network:8547/ws,ws://conductor-2-test-network:8547/ws"
    )
    expect.eq(config.env_vars["UPSTREAM_WS"], expected_upstream)


def test_flashblocks_websocket_proxy_get_service_config_single_conductor(plan):
    """Test service config generation with single conductor"""

    # Mock parameters
    params = struct(
        image="test/flashblocks-proxy:latest",
        ports={
            "ws": _net.port(number=8545, transport_protocol="TCP"),
            "metrics": _net.port(number=9000, transport_protocol="TCP"),
        },
        labels={},
    )

    # Mock single conductor context
    conductor = struct(
        service_name="conductor-solo-test-network", conductor_rpc_port=8547
    )
    conductors_contexts = [conductor]

    # Mock observability helper
    observability_helper = struct(enabled=False)

    config = flashblocks_websocket_proxy_launcher.get_service_config(
        plan=plan,
        params=params,
        conductors_contexts=conductors_contexts,
        observability_helper=observability_helper,
    )

    # Verify single upstream URL
    expected_upstream = "ws://conductor-solo-test-network:8547/ws"
    expect.eq(config.env_vars["UPSTREAM_WS"], expected_upstream)


def test_flashblocks_websocket_proxy_upstream_ws_order(plan):
    """Ensure UPSTREAM_WS preserves conductor order and formatting"""

    params = struct(
        image="test/flashblocks-proxy:latest",
        ports={
            "ws": _net.port(number=8545, transport_protocol="TCP"),
            "metrics": _net.port(number=9000, transport_protocol="TCP"),
        },
        labels={},
    )

    conductors_contexts = [
        struct(service_name="c-a", conductor_rpc_port=8547),
        struct(service_name="c-b", conductor_rpc_port=9547),
        struct(service_name="c-c", conductor_rpc_port=10547),
    ]

    observability_helper = struct(enabled=False)

    config = flashblocks_websocket_proxy_launcher.get_service_config(
        plan=plan,
        params=params,
        conductors_contexts=conductors_contexts,
        observability_helper=observability_helper,
    )

    expect.eq(
        config.env_vars["UPSTREAM_WS"],
        "ws://c-a:8547/ws,ws://c-b:9547/ws,ws://c-c:10547/ws",
    )


def test_flashblocks_websocket_proxy_environment_variables(plan):
    """Test that all required environment variables are set correctly"""

    # Mock parameters
    params = struct(
        image="test/flashblocks-proxy:latest",
        ports={
            "ws": _net.port(number=8545, transport_protocol="TCP"),
            "metrics": _net.port(number=9000, transport_protocol="TCP"),
        },
        labels={},
    )

    # Mock observability helper
    observability_helper = struct(enabled=False)

    config = flashblocks_websocket_proxy_launcher.get_service_config(
        plan=plan,
        params=params,
        conductors_contexts=[],
        observability_helper=observability_helper,
    )

    # Verify all expected environment variables
    expected_env_vars = {
        "GLOBAL_CONNECTIONS_LIMIT": "100",
        "IP_ADDR_HTTP_HEADER": "X-Forwarded-For",
        "LISTEN_ADDR": "0.0.0.0:8545",
        "LOG_FORMAT": "text",
        "LOG_LEVEL": "info",
        "MESSAGE_BUFFER_SIZE": "20",
        "METRICS": "true",
        "METRICS_ADDR": "0.0.0.0:9000",
        "PER_IP_CONNECTIONS_LIMIT": "10",
        "UPSTREAM_WS": "",
    }

    for key, expected_value in expected_env_vars.items():
        expect.eq(config.env_vars[key], expected_value)


def test_flashblocks_websocket_proxy_launch_function(plan):
    """Test the main launch function"""

    # Mock parameters
    params = struct(
        image="test/flashblocks-proxy:latest",
        service_name="flashblocks-websocket-proxy-test",
        ports={
            "ws": _net.port(number=8545, transport_protocol="TCP"),
            "metrics": _net.port(number=9000, transport_protocol="TCP"),
        },
        labels={},
    )

    # Mock network params
    network_params = struct(network_id="2151908", name="test-network")

    # Mock observability helper
    observability_helper = struct(enabled=False)

    # Test that launch returns expected structure
    result = flashblocks_websocket_proxy_launcher.launch(
        plan=plan,
        params=params,
        conductors_contexts=[],
        observability_helper=observability_helper,
    )

    # The result should be a struct with context
    # Note: In real implementation, this would add a service to plan
    # For testing, we just verify the function runs without error
    expect.ne(result, None)
