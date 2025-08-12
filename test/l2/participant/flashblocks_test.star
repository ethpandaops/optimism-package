participant_input_parser = import_module("/src/l2/participant/input_parser.star")
_registry = import_module("/src/package_io/registry.star")

_default_registry = _registry.Registry()


def test_participant_use_flashblocks_default(plan):
    """Test that use_flashblocks defaults to False"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    participant_args = {
        "el": {"type": "op-reth"},
        "cl": {"type": "op-node"}
    }
    
    result = participant_input_parser._parse_instance(
        participant_args=participant_args,
        participant_name="test-participant",
        participant_index_generator=lambda: 0,
        network_params=network_params,
        registry=_default_registry,
    )
    
    expect.eq(result.use_flashblocks, False)


def test_participant_use_flashblocks_enabled(plan):
    """Test that use_flashblocks can be enabled"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    participant_args = {
        "el": {"type": "op-reth"},
        "cl": {"type": "op-node"},
        "use_flashblocks": True
    }
    
    result = participant_input_parser._parse_instance(
        participant_args=participant_args,
        participant_name="flashblocks-participant",
        participant_index_generator=lambda: 0,
        network_params=network_params,
        registry=_default_registry,
    )
    
    expect.eq(result.use_flashblocks, True)


def test_participant_use_flashblocks_disabled_explicitly(plan):
    """Test that use_flashblocks can be explicitly disabled"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    participant_args = {
        "el": {"type": "op-reth"},
        "cl": {"type": "op-node"},
        "use_flashblocks": False
    }
    
    result = participant_input_parser._parse_instance(
        participant_args=participant_args,
        participant_name="non-flashblocks-participant",
        participant_index_generator=lambda: 0,
        network_params=network_params,
        registry=_default_registry,
    )
    
    expect.eq(result.use_flashblocks, False)


def test_participant_flashblocks_with_mev(plan):
    """Test that flashblocks participants can have MEV configuration"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    participant_args = {
        "el": {"type": "op-reth"},
        "cl": {"type": "op-node"},
        "use_flashblocks": True,
        "mev_params": {
            "enabled": True,
            "type": "rollup-boost"
        },
        "el_builder": {"type": "op-rbuilder"},
        "cl_builder": {"type": "op-node"}
    }
    
    result = participant_input_parser._parse_instance(
        participant_args=participant_args,
        participant_name="flashblocks-mev-participant",
        participant_index_generator=lambda: 0,
        network_params=network_params,
        registry=_default_registry,
    )
    
    expect.eq(result.use_flashblocks, True)
    expect.ne(result.mev_params, None)
    expect.ne(result.el_builder, None)
    expect.ne(result.cl_builder, None)


def test_participant_flashblocks_sequencer_inheritance(plan):
    """Test that use_flashblocks is preserved through sequencer processing"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    # Create participants with different flashblocks settings
    participants_args = {
        "sequencer-0": {
            "sequencer": True,
            "el": {"type": "op-geth"},
            "cl": {"type": "op-node"},
            "conductor_params": {"enabled": True}
        },
        "flashblocks-rpc": {
            "sequencer": "sequencer-0",  # Explicit sequencer reference
            "el": {"type": "op-reth"},
            "cl": {"type": "op-node"},
            "use_flashblocks": True
        },
        "regular-rpc": {
            "sequencer": "sequencer-0",  # Explicit sequencer reference
            "el": {"type": "op-reth"},
            "cl": {"type": "op-node"},
            "use_flashblocks": False
        }
    }
    
    result = participant_input_parser.parse(
        args=participants_args,
        network_params=network_params,
        registry=_default_registry,
    )
    
    # Find participants by name
    sequencer = None
    flashblocks_rpc = None
    regular_rpc = None
    
    for p in result:
        if p.name == "sequencer-0":
            sequencer = p
        elif p.name == "flashblocks-rpc":
            flashblocks_rpc = p
        elif p.name == "regular-rpc":
            regular_rpc = p
    
    # Verify use_flashblocks is preserved correctly
    expect.eq(sequencer.use_flashblocks, False)  # Default for sequencer
    expect.eq(flashblocks_rpc.use_flashblocks, True)
    expect.eq(regular_rpc.use_flashblocks, False)


def test_participant_flashblocks_with_sequencer_reference(plan):
    """Test flashblocks participants that reference a sequencer"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    participants_args = {
        "sequencer-0": {
            "sequencer": True,
            "el": {"type": "op-geth"},
            "cl": {"type": "op-node"},
            "conductor_params": {"enabled": True}
        },
        "flashblocks-replica": {
            "sequencer": "sequencer-0",  # Reference to sequencer
            "el": {"type": "op-reth"},
            "cl": {"type": "op-node"},
            "use_flashblocks": True
        }
    }
    
    result = participant_input_parser.parse(
        args=participants_args,
        network_params=network_params,
        registry=_default_registry,
    )
    
    # Find the flashblocks replica
    flashblocks_replica = None
    for p in result:
        if p.name == "flashblocks-replica":
            flashblocks_replica = p
            break
    
    expect.ne(flashblocks_replica, None)
    expect.eq(flashblocks_replica.use_flashblocks, True)
    expect.eq(flashblocks_replica.sequencer, "sequencer-0")


def test_participant_invalid_flashblocks_type(plan):
    """Test that invalid use_flashblocks type is handled"""
    
    network_params = struct(
        network_id="2151908",
        name="test-network"
    )
    
    participant_args = {
        "el": {"type": "op-reth"},
        "cl": {"type": "op-node"},
        "use_flashblocks": "invalid"  # Should be boolean
    }
    
    # This should not fail during parsing since Starlark is dynamically typed
    # but the value should be treated as truthy
    result = participant_input_parser._parse_instance(
        participant_args=participant_args,
        participant_name="test-participant",
        participant_index_generator=lambda: 0,
        network_params=network_params,
        registry=_default_registry,
    )
    
    # Non-empty string is truthy in Starlark
    expect.eq(result.use_flashblocks, "invalid")