flashblocks_input_parser = import_module("/src/flashblocks/input_parser.star")
_registry = import_module("/src/package_io/registry.star")

_default_registry = _registry.Registry()


def test_flashblocks_websocket_proxy_parser_empty(plan):
    """Test parsing empty flashblocks websocket proxy configuration"""
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(None, network_params, _default_registry)
    expect.eq(result, None)


def test_flashblocks_websocket_proxy_parser_disabled(plan):
    """Test parsing disabled flashblocks websocket proxy configuration"""
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(
        {"enabled": False}, network_params, _default_registry
    )
    expect.eq(result, None)


def test_flashblocks_websocket_proxy_parser_enabled_defaults(plan):
    """Test parsing enabled flashblocks websocket proxy with default values"""
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(
        {"enabled": True}, network_params, _default_registry
    )
    
    expect.eq(result.enabled, True)
    # Note: Registry may not have FLASHBLOCKS_WEBSOCKET_PROXY key, check if enabled
    expect.ne(result.image, None)
    # Check service name includes network info
    expect.contains(result.service_name, "flashblocks-websocket-proxy")
    expect.eq(len(result.ports), 2)
    
    # Check ports
    ws_port = result.ports["ws"]
    metrics_port = result.ports["metrics"]
    expect.eq(ws_port.number, 8545)
    expect.eq(ws_port.transport_protocol, "TCP")
    expect.eq(metrics_port.number, 9000)
    expect.eq(metrics_port.transport_protocol, "TCP")


def test_flashblocks_websocket_proxy_parser_custom_image(plan):
    """Test parsing flashblocks websocket proxy with custom image"""
    custom_image = "custom/flashblocks-proxy:latest"
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(
        {"enabled": True, "image": custom_image}, network_params, _default_registry
    )
    
    expect.eq(result.enabled, True)
    expect.eq(result.image, custom_image)


def test_flashblocks_websocket_proxy_parser_custom_ports(plan):
    """Test parsing flashblocks websocket proxy with custom ports"""
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(
        {
            "enabled": True,
            "ports": {
                "ws": 9545,
                "metrics": 10000
            }
        }, 
        network_params, _default_registry
    )
    
    expect.eq(result.enabled, True)
    expect.eq(result.ports["ws"].number, 9545)
    expect.eq(result.ports["metrics"].number, 10000)


def test_flashblocks_websocket_proxy_parser_custom_labels(plan):
    """Test parsing flashblocks websocket proxy with custom labels"""
    custom_labels = {
        "app": "flashblocks-proxy",
        "version": "v1.0.0"
    }
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(
        {
            "enabled": True,
            "labels": custom_labels
        }, 
        network_params, _default_registry
    )
    
    expect.eq(result.enabled, True)
    # Check that custom labels are merged with defaults
    expect.eq(result.labels["app"], "flashblocks-proxy")
    expect.eq(result.labels["version"], "v1.0.0")
    # Verify default labels are still present
    expect.eq(result.labels["op.kind"], "flashblocks")


def test_flashblocks_websocket_proxy_parser_invalid_args(plan):
    """Test that invalid arguments are rejected"""
    network_params = struct(name="test-network", network_id="2151908")
    expect.fails(
        lambda: flashblocks_input_parser.parse_websocket_proxy(
            {"enabled": True, "invalid_arg": "value"}, network_params, _default_registry
        ),
        "Invalid attributes in flashblocks websocket proxy configuration for network test-network",
    )


def test_flashblocks_websocket_proxy_parser_resource_limits(plan):
    """Test parsing flashblocks websocket proxy with resource limits"""
    network_params = struct(name="test-network", network_id="2151908")
    result = flashblocks_input_parser.parse_websocket_proxy(
        {
            "enabled": True,
            "min_cpu": 500,
            "max_cpu": 1000,
            "min_mem": 512,
            "max_mem": 1024
        }, 
        network_params, _default_registry
    )
    
    expect.eq(result.enabled, True)
    expect.eq(result.min_cpu, 500)
    expect.eq(result.max_cpu, 1000)
    expect.eq(result.min_mem, 512)
    expect.eq(result.max_mem, 1024)


def test_flashblocks_websocket_proxy_parser_tolerations_node_selectors(plan):
    """Test parsing flashblocks websocket proxy with tolerations and node selectors"""
    tolerations = [{"key": "node-type", "value": "compute"}]
    node_selectors = {"zone": "us-east-1a"}
    network_params = struct(name="test-network", network_id="2151908")
    
    result = flashblocks_input_parser.parse_websocket_proxy(
        {
            "enabled": True,
            "tolerations": tolerations,
            "node_selectors": node_selectors
        }, 
        network_params, _default_registry
    )
    
    expect.eq(result.enabled, True)
    expect.eq(result.tolerations, tolerations)
    expect.eq(result.node_selectors, node_selectors)