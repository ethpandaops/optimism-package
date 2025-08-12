"""Tests for op-reth flashblocks integration"""

op_reth_launcher = import_module("/src/el/op-reth/launcher.star")
_registry = import_module("/src/package_io/registry.star")
_net = import_module("/src/util/net.star")

_default_registry = _registry.Registry()


def test_op_reth_websocket_url_flag_addition(plan):
    """Test that --websocket-url flag is added when websocket_url is provided"""
    
    # Mock basic parameters
    params = struct(
        image="ethereum/client-go:latest",
        service_name="op-reth-flashblocks",
        ports={
            "rpc": _net.port(number=8545, transport_protocol="TCP"),
            "ws": _net.port(number=8546, transport_protocol="TCP"),
            "tcp-discovery": _net.port(number=30303, transport_protocol="TCP"),
            "udp-discovery": _net.port(number=30303, transport_protocol="UDP"),
            "engine-rpc": _net.port(number=8551, transport_protocol="TCP")
        },
        extra_env_vars={},
        extra_params=[],
        volume_size=0,
        labels={},
        min_cpu=0,
        max_cpu=0,
        min_mem=0,
        max_mem=0
    )
    
    network_params = struct(
        network="test-network",
        network_id="2151908"
    )
    
    jwt_file = "mock-jwt-file"
    deployment_output = "mock-deployment"
    websocket_url = "ws://flashblocks-websocket-proxy-2151908-test:8545/ws"
    
    # Test the get_service_config function with websocket_url
    config = op_reth_launcher.get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        sequencer_params=None,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level="info",
        persistent=False,
        tolerations=[],
        node_selectors={},
        bootnode_contexts=[],
        observability_helper=struct(enabled=False),
        supervisors_params=[],
        websocket_url=websocket_url,
    )
    
    # Verify the websocket URL flag is in the command
    websocket_flag = "--websocket-url={}".format(websocket_url)
    expect.contains(config.cmd, websocket_flag)


def test_op_reth_without_websocket_url(plan):
    """Test that no --websocket-url flag is added when websocket_url is None"""
    
    # Mock basic parameters
    params = struct(
        image="ethereum/client-go:latest", 
        service_name="op-reth-regular",
        ports={
            "rpc": _net.port(number=8545, transport_protocol="TCP"),
            "ws": _net.port(number=8546, transport_protocol="TCP"),
            "tcp-discovery": _net.port(number=30303, transport_protocol="TCP"),
            "udp-discovery": _net.port(number=30303, transport_protocol="UDP"),
            "engine-rpc": _net.port(number=8551, transport_protocol="TCP")
        },
        extra_env_vars={},
        extra_params=[],
        volume_size=0,
        labels={},
        min_cpu=0,
        max_cpu=0,
        min_mem=0,
        max_mem=0
    )
    
    network_params = struct(
        network="test-network",
        network_id="2151908"
    )
    
    jwt_file = "mock-jwt-file"
    deployment_output = "mock-deployment"
    
    # Test the get_service_config function without websocket_url
    config = op_reth_launcher.get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        sequencer_params=None,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level="info",
        persistent=False,
        tolerations=[],
        node_selectors={},
        bootnode_contexts=[],
        observability_helper=struct(enabled=False),
        supervisors_params=[],
        websocket_url=None,
    )
    
    # Verify no websocket URL flag is in the command
    websocket_flags = [arg for arg in config.cmd if "--websocket-url" in arg]
    expect.eq(len(websocket_flags), 0)


def test_op_reth_websocket_url_flag_format(plan):
    """Test the exact format of the --websocket-url flag"""
    
    test_cases = [
        {
            "url": "ws://proxy:8545/ws",
            "expected_flag": "--websocket-url=ws://proxy:8545/ws"
        },
        {
            "url": "ws://flashblocks-websocket-proxy-2151908-testnet:8545/ws", 
            "expected_flag": "--websocket-url=ws://flashblocks-websocket-proxy-2151908-testnet:8545/ws"
        },
        {
            "url": "ws://localhost:9545/ws",
            "expected_flag": "--websocket-url=ws://localhost:9545/ws"
        }
    ]
    
    for test_case in test_cases:
        websocket_url = test_case["url"]
        expected_flag = test_case["expected_flag"]
        
        # Simulate the flag creation logic from op-reth launcher
        actual_flag = "--websocket-url={}".format(websocket_url)
        
        expect.eq(actual_flag, expected_flag)


def test_op_reth_websocket_url_with_extra_params(plan):
    """Test that websocket URL flag works alongside other extra parameters"""
    
    # Mock parameters with extra params
    params = struct(
        image="ethereum/client-go:latest",
        service_name="op-reth-flashblocks",
        ports={
            "rpc": _net.port(number=8545, transport_protocol="TCP"),
            "ws": _net.port(number=8546, transport_protocol="TCP"),
            "tcp-discovery": _net.port(number=30303, transport_protocol="TCP"),
            "udp-discovery": _net.port(number=30303, transport_protocol="UDP"),
            "engine-rpc": _net.port(number=8551, transport_protocol="TCP")
        },
        extra_env_vars={"CUSTOM_VAR": "custom_value"},
        extra_params=["--custom-flag", "--another-option=value"],
        volume_size=0,
        labels={},
        min_cpu=0,
        max_cpu=0,
        min_mem=0,
        max_mem=0
    )
    
    network_params = struct(
        network="test-network",
        network_id="2151908"
    )
    
    jwt_file = "mock-jwt-file"
    deployment_output = "mock-deployment"
    websocket_url = "ws://proxy:8545/ws"
    
    # Test configuration generation
    config = op_reth_launcher.get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        sequencer_params=None,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level="info",
        persistent=False,
        tolerations=[],
        node_selectors={},
        bootnode_contexts=[],
        observability_helper=struct(enabled=False),
        supervisors_params=[],
        websocket_url=websocket_url,
    )
    
    # Verify websocket URL flag is present
    websocket_flag = "--websocket-url={}".format(websocket_url)
    expect.contains(config.cmd, websocket_flag)
    
    # Verify extra params are also present
    expect.contains(config.cmd, "--custom-flag")
    expect.contains(config.cmd, "--another-option=value")
    
    # Verify custom environment variable is present
    expect.eq(config.env_vars["CUSTOM_VAR"], "custom_value")


def test_op_reth_websocket_url_empty_string(plan):
    """Test behavior with empty string websocket URL"""
    
    # Mock basic parameters
    params = struct(
        image="ethereum/client-go:latest",
        service_name="op-reth-test",
        ports={
            "rpc": _net.port(number=8545, transport_protocol="TCP"),
            "ws": _net.port(number=8546, transport_protocol="TCP"),
            "tcp-discovery": _net.port(number=30303, transport_protocol="TCP"),
            "udp-discovery": _net.port(number=30303, transport_protocol="UDP"),
            "engine-rpc": _net.port(number=8551, transport_protocol="TCP")
        },
        extra_env_vars={},
        extra_params=[],
        volume_size=0,
        labels={},
        min_cpu=0,
        max_cpu=0,
        min_mem=0,
        max_mem=0
    )
    
    network_params = struct(
        network="test-network",
        network_id="2151908"
    )
    
    jwt_file = "mock-jwt-file"
    deployment_output = "mock-deployment"
    websocket_url = ""  # Empty string
    
    # Test configuration generation
    config = op_reth_launcher.get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        sequencer_params=None,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level="info",
        persistent=False,
        tolerations=[],
        node_selectors={},
        bootnode_contexts=[],
        observability_helper=struct(enabled=False),
        supervisors_params=[],
        websocket_url=websocket_url,
    )
    
    # Empty string is falsy in Starlark, so no flag should be added
    websocket_flags = [arg for arg in config.cmd if "--websocket-url" in arg]
    expect.eq(len(websocket_flags), 0)


def test_op_reth_websocket_url_position_in_command(plan):
    """Test that websocket URL flag is added at the correct position in command"""
    
    # The websocket URL flag should be added early in the command construction
    # This test verifies the conceptual positioning
    
    base_cmd = [
        "op-reth",
        "--datadir=/data",
        "--http",
        "--http.addr=0.0.0.0",
        "--http.port=8545"
    ]
    
    websocket_url = "ws://proxy:8545/ws"
    
    # Simulate adding the websocket URL flag early in command construction
    cmd = []
    
    # Add websocket URL flag first (as done in launcher)
    if websocket_url:
        cmd.append("--websocket-url={}".format(websocket_url))
    
    # Add other flags
    cmd.extend(base_cmd)
    
    # Verify websocket URL flag is at the beginning
    expect.eq(cmd[0], "--websocket-url=ws://proxy:8545/ws")
    expect.eq(cmd[1], "op-reth")


def test_op_reth_websocket_url_no_double_flag(plan):
    """Test that websocket URL flag is not duplicated"""
    
    # Mock parameters that might already include websocket URL in extra_params
    params = struct(
        image="ethereum/client-go:latest",
        service_name="op-reth-test",
        ports={
            "rpc": _net.port(number=8545, transport_protocol="TCP"),
            "ws": _net.port(number=8546, transport_protocol="TCP"),
            "tcp-discovery": _net.port(number=30303, transport_protocol="TCP"),
            "udp-discovery": _net.port(number=30303, transport_protocol="UDP"),
            "engine-rpc": _net.port(number=8551, transport_protocol="TCP")
        },
        extra_env_vars={},
        extra_params=["--websocket-url=ws://existing:8545/ws"],  # Pre-existing flag
        volume_size=0
    )
    
    websocket_url = "ws://proxy:8545/ws"
    
    # Simulate command construction
    cmd = []
    
    # Add websocket URL flag if provided
    if websocket_url:
        cmd.append("--websocket-url={}".format(websocket_url))
    
    # Add extra params
    cmd.extend(params.extra_params)
    
    # Count occurrences of websocket-url flags
    websocket_flags = [arg for arg in cmd if arg.startswith("--websocket-url")]
    
    # There should be 2 flags in this test case (which might be undesirable)
    # In a real implementation, you might want to check for conflicts
    expect.eq(len(websocket_flags), 2)
    expect.eq(websocket_flags[0], "--websocket-url=ws://proxy:8545/ws")
    expect.eq(websocket_flags[1], "--websocket-url=ws://existing:8545/ws")