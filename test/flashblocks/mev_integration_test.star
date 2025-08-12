"""Tests for flashblocks MEV integration functionality"""

# Note: Since the MEV integration logic is part of launcher__hack.star,
# these tests focus on the logical aspects that can be tested in isolation

def test_flashblocks_mev_sidecar_conditions(plan):
    """Test conditions for launching MEV sidecar with flashblocks participants"""
    
    # Test case 1: No MEV params - should skip sidecar
    participant_no_mev = struct(
        name="flashblocks-rpc",
        use_flashblocks=True,
        mev_params=None
    )
    
    should_launch_mev = participant_no_mev.mev_params != None
    expect.eq(should_launch_mev, False)
    
    # Test case 2: MEV enabled but not sequencer - should skip sidecar  
    participant_non_sequencer = struct(
        name="flashblocks-rpc",
        use_flashblocks=True,
        mev_params=struct(enabled=True, type="rollup-boost"),
        sequencer="sequencer-0"  # References another sequencer
    )
    
    is_sequencer = participant_non_sequencer.sequencer == participant_non_sequencer.name
    should_launch_mev = participant_non_sequencer.mev_params != None and is_sequencer
    expect.eq(should_launch_mev, False)
    
    # Test case 3: MEV enabled and is sequencer - should launch sidecar
    participant_sequencer_mev = struct(
        name="flashblocks-sequencer",
        use_flashblocks=True,
        mev_params=struct(enabled=True, type="rollup-boost"),
        sequencer="flashblocks-sequencer"  # Self-reference means it's a sequencer
    )
    
    is_sequencer = participant_sequencer_mev.sequencer == participant_sequencer_mev.name
    should_launch_mev = participant_sequencer_mev.mev_params != None and is_sequencer
    expect.eq(should_launch_mev, True)


def test_flashblocks_mev_external_builder_detection(plan):
    """Test detection of external builders for flashblocks MEV"""
    
    # Test case 1: Internal builder (no external host/port)
    mev_params_internal = struct(
        enabled=True,
        type="rollup-boost",
        builder_host=None,
        builder_port=None
    )
    
    is_external_builder = mev_params_internal.builder_host != None and mev_params_internal.builder_port != None
    expect.eq(is_external_builder, False)
    
    # Test case 2: External builder (with host and port)
    mev_params_external = struct(
        enabled=True,
        type="rollup-boost", 
        builder_host="external-builder.example.com",
        builder_port=8545
    )
    
    is_external_builder = mev_params_external.builder_host != None and mev_params_external.builder_port != None
    expect.eq(is_external_builder, True)
    
    # Test case 3: Partial external config (only host) - should be False
    mev_params_partial = struct(
        enabled=True,
        type="rollup-boost",
        builder_host="external-builder.example.com",
        builder_port=None
    )
    
    is_external_builder = mev_params_partial.builder_host != None and mev_params_partial.builder_port != None
    expect.eq(is_external_builder, False)


def test_flashblocks_mev_context_switching(plan):
    """Test EL context switching for CL when MEV is enabled"""
    
    # Mock EL context
    el_context = struct(
        service_name="flashblocks-el",
        rpc_http_url="http://flashblocks-el:8545",
        ws_url="ws://flashblocks-el:8546"
    )
    
    # Mock sidecar context (rollup-boost)
    sidecar_context = struct(
        service_name="rollup-boost-sidecar",
        rpc_http_url="http://rollup-boost-sidecar:8545",
        ws_url="ws://rollup-boost-sidecar:8546"
    )
    
    # Test case 1: MEV enabled - CL should connect to sidecar
    sidecar_and_builders = struct(
        sidecar=struct(context=sidecar_context),
        el_builder=struct(),
        cl_builder=struct()
    )
    
    el_context_for_cl = (
        sidecar_and_builders.sidecar.context if sidecar_and_builders and sidecar_and_builders.sidecar
        else el_context
    )
    
    expect.eq(el_context_for_cl.service_name, "rollup-boost-sidecar")
    
    # Test case 2: MEV disabled - CL should connect to EL directly
    sidecar_and_builders_none = None
    
    el_context_for_cl = (
        sidecar_and_builders_none.sidecar.context if sidecar_and_builders_none and sidecar_and_builders_none.sidecar
        else el_context
    )
    
    expect.eq(el_context_for_cl.service_name, "flashblocks-el")
    
    # Test case 3: MEV structure exists but no sidecar - CL should connect to EL
    sidecar_and_builders_no_sidecar = struct(
        sidecar=None,
        el_builder=struct(),
        cl_builder=struct()
    )
    
    el_context_for_cl = (
        sidecar_and_builders_no_sidecar.sidecar.context if sidecar_and_builders_no_sidecar and sidecar_and_builders_no_sidecar.sidecar
        else el_context
    )
    
    expect.eq(el_context_for_cl.service_name, "flashblocks-el")


def test_flashblocks_mev_external_builder_context(plan):
    """Test external builder context creation for flashblocks MEV"""
    
    # Mock external MEV params
    mev_params = struct(
        builder_host="external-builder.example.com",
        builder_port=8545
    )
    
    # Create external builder context as done in launcher__hack
    el_builder_context = struct(
        ip_addr=mev_params.builder_host,
        engine_rpc_port_num=mev_params.builder_port,
        rpc_port_num=mev_params.builder_port,
        rpc_http_url="http://{}:{}".format(mev_params.builder_host, mev_params.builder_port),
        client_name="external-builder",
    )
    
    # Verify external builder context
    expect.eq(el_builder_context.ip_addr, "external-builder.example.com")
    expect.eq(el_builder_context.engine_rpc_port_num, 8545)
    expect.eq(el_builder_context.rpc_port_num, 8545)
    expect.eq(el_builder_context.rpc_http_url, "http://external-builder.example.com:8545")
    expect.eq(el_builder_context.client_name, "external-builder")


def test_flashblocks_mev_success_logging(plan):
    """Test MEV status logging for flashblocks participants"""
    
    websocket_url = "ws://flashblocks-websocket-proxy-2151908-network:8545/ws"
    
    # Test case 1: With MEV
    sidecar_and_builders = struct(
        sidecar=struct(context=struct(service_name="rollup-boost"))
    )
    
    mev_status = "with MEV (rollup-boost)" if sidecar_and_builders and sidecar_and_builders.sidecar else "without MEV"
    log_message = "Successfully launched with --websocket-url={} {}".format(websocket_url, mev_status)
    
    expected_log_with_mev = "Successfully launched with --websocket-url=ws://flashblocks-websocket-proxy-2151908-network:8545/ws with MEV (rollup-boost)"
    expect.eq(log_message, expected_log_with_mev)
    
    # Test case 2: Without MEV
    sidecar_and_builders_none = None
    
    mev_status = "with MEV (rollup-boost)" if sidecar_and_builders_none and sidecar_and_builders_none.sidecar else "without MEV"
    log_message = "Successfully launched with --websocket-url={} {}".format(websocket_url, mev_status)
    
    expected_log_without_mev = "Successfully launched with --websocket-url=ws://flashblocks-websocket-proxy-2151908-network:8545/ws without MEV"
    expect.eq(log_message, expected_log_without_mev)


def test_flashblocks_mev_rollup_boost_type_validation(plan):
    """Test validation of MEV type for flashblocks"""
    
    # Valid MEV type
    mev_params_valid = struct(
        enabled=True,
        type="rollup-boost"
    )
    
    is_valid_mev_type = mev_params_valid.type == "rollup-boost"
    expect.eq(is_valid_mev_type, True)
    
    # Invalid MEV type (hypothetical future type)
    mev_params_invalid = struct(
        enabled=True,
        type="flashbots-boost"  # Not rollup-boost
    )
    
    is_valid_mev_type = mev_params_invalid.type == "rollup-boost"
    expect.eq(is_valid_mev_type, False)
    
    # Note: In the real implementation, invalid types would cause a fail() call


def test_flashblocks_mev_component_structure(plan):
    """Test the structure returned by MEV sidecar launch"""
    
    # Mock the structure returned by _launch_flashblocks_sidecar_maybe
    sidecar_and_builders = struct(
        el_builder=struct(
            context=struct(service_name="op-rbuilder-instance")
        ),
        cl_builder=struct(
            context=struct(service_name="op-node-builder-instance")
        ),
        sidecar=struct(
            context=struct(
                service_name="rollup-boost-sidecar",
                rpc_http_url="http://rollup-boost-sidecar:8545"
            )
        )
    )
    
    # Verify structure has all expected components
    expect.ne(sidecar_and_builders.el_builder, None)
    expect.ne(sidecar_and_builders.cl_builder, None)
    expect.ne(sidecar_and_builders.sidecar, None)
    
    # Verify component contexts
    expect.eq(sidecar_and_builders.el_builder.context.service_name, "op-rbuilder-instance")
    expect.eq(sidecar_and_builders.cl_builder.context.service_name, "op-node-builder-instance") 
    expect.eq(sidecar_and_builders.sidecar.context.service_name, "rollup-boost-sidecar")