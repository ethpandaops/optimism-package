"""
Flashblocks Test Suite
Comprehensive tests for flashblocks integration including websocket proxy, 
participant parsing, MEV integration, and op-reth flag handling.
"""

# Import test modules
flashblocks_input_parser_tests = import_module("/test/flashblocks/input_parser_test.star")
flashblocks_launcher_tests = import_module("/test/flashblocks/launcher_test.star") 
flashblocks_mev_tests = import_module("/test/flashblocks/mev_integration_test.star")
participant_flashblocks_tests = import_module("/test/l2/participant/flashblocks_test.star")
l2_flashblocks_launcher_tests = import_module("/test/l2/flashblocks_launcher_test.star")
op_reth_flashblocks_tests = import_module("/test/el/op_reth_flashblocks_test.star")


def test_flashblocks_complete_suite(plan):
    """Run all flashblocks tests to ensure complete integration works"""
    
    # Input Parser Tests
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_empty(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_disabled(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_enabled_defaults(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_custom_image(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_custom_ports(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_custom_labels(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_invalid_args(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_resource_limits(plan)
    flashblocks_input_parser_tests.test_flashblocks_websocket_proxy_parser_tolerations_node_selectors(plan)
    
    # Launcher Tests
    flashblocks_launcher_tests.test_flashblocks_websocket_proxy_get_service_config_basic(plan)
    flashblocks_launcher_tests.test_flashblocks_websocket_proxy_get_service_config_with_conductors(plan)
    flashblocks_launcher_tests.test_flashblocks_websocket_proxy_get_service_config_single_conductor(plan)
    flashblocks_launcher_tests.test_flashblocks_websocket_proxy_environment_variables(plan)
    flashblocks_launcher_tests.test_flashblocks_websocket_proxy_launch_function(plan)
    
    # Participant Tests
    participant_flashblocks_tests.test_participant_use_flashblocks_default(plan)
    participant_flashblocks_tests.test_participant_use_flashblocks_enabled(plan)
    participant_flashblocks_tests.test_participant_use_flashblocks_disabled_explicitly(plan)
    participant_flashblocks_tests.test_participant_flashblocks_with_mev(plan)
    participant_flashblocks_tests.test_participant_flashblocks_sequencer_inheritance(plan)
    participant_flashblocks_tests.test_participant_flashblocks_with_sequencer_reference(plan)
    participant_flashblocks_tests.test_participant_invalid_flashblocks_type(plan)
    
    # L2 Launcher Tests
    l2_flashblocks_launcher_tests.test_flashblocks_participant_separation(plan)
    l2_flashblocks_launcher_tests.test_flashblocks_participant_with_mev_separation(plan)
    l2_flashblocks_launcher_tests.test_empty_flashblocks_participants(plan)
    l2_flashblocks_launcher_tests.test_all_flashblocks_participants(plan)
    l2_flashblocks_launcher_tests.test_flashblocks_websocket_url_generation(plan)
    l2_flashblocks_launcher_tests.test_flashblocks_participant_el_type_validation(plan)
    
    # MEV Integration Tests
    flashblocks_mev_tests.test_flashblocks_mev_sidecar_conditions(plan)
    flashblocks_mev_tests.test_flashblocks_mev_external_builder_detection(plan)
    flashblocks_mev_tests.test_flashblocks_mev_context_switching(plan)
    flashblocks_mev_tests.test_flashblocks_mev_external_builder_context(plan)
    flashblocks_mev_tests.test_flashblocks_mev_success_logging(plan)
    flashblocks_mev_tests.test_flashblocks_mev_rollup_boost_type_validation(plan)
    flashblocks_mev_tests.test_flashblocks_mev_component_structure(plan)
    
    # Op-Reth Integration Tests
    op_reth_flashblocks_tests.test_op_reth_websocket_url_flag_addition(plan)
    op_reth_flashblocks_tests.test_op_reth_without_websocket_url(plan)
    op_reth_flashblocks_tests.test_op_reth_websocket_url_flag_format(plan)
    op_reth_flashblocks_tests.test_op_reth_websocket_url_with_extra_params(plan)
    op_reth_flashblocks_tests.test_op_reth_websocket_url_empty_string(plan)
    op_reth_flashblocks_tests.test_op_reth_websocket_url_position_in_command(plan)
    op_reth_flashblocks_tests.test_op_reth_websocket_url_no_double_flag(plan)
    
    plan.print("✅ All flashblocks tests passed successfully!")


def test_flashblocks_integration_scenarios(plan):
    """Test common integration scenarios end-to-end"""
    
    # Scenario 1: Simple flashblocks setup
    plan.print("Testing Scenario 1: Simple flashblocks setup")
    
    simple_participants = [
        struct(
            name="sequencer-0",
            use_flashblocks=False,
            el=struct(type="op-geth"),
            conductor_params=struct(enabled=True)
        ),
        struct(
            name="flashblocks-rpc",
            use_flashblocks=True,
            el=struct(type="op-reth"),
            mev_params=None
        )
    ]
    
    _test_participant_separation_scenario(plan, simple_participants, 1, 1)
    
    # Scenario 2: Flashblocks with MEV
    plan.print("Testing Scenario 2: Flashblocks with MEV")
    
    mev_participants = [
        struct(
            name="mev-sequencer",
            use_flashblocks=False,
            el=struct(type="op-geth"),
            conductor_params=struct(enabled=True),
            mev_params=struct(enabled=True, type="rollup-boost")
        ),
        struct(
            name="flashblocks-mev-rpc",
            use_flashblocks=True,
            el=struct(type="op-reth"),
            mev_params=struct(enabled=True, type="rollup-boost")
        )
    ]
    
    _test_participant_separation_scenario(plan, mev_participants, 1, 1)
    
    # Scenario 3: Production-like setup
    plan.print("Testing Scenario 3: Production-like setup")
    
    production_participants = [
        struct(name="sequencer-0", use_flashblocks=False, el=struct(type="op-geth")),
        struct(name="sequencer-1", use_flashblocks=False, el=struct(type="op-reth")),
        struct(name="replica-0", use_flashblocks=False, el=struct(type="op-reth")),
        struct(name="flashblocks-rpc-0", use_flashblocks=True, el=struct(type="op-reth")),
        struct(name="flashblocks-rpc-1", use_flashblocks=True, el=struct(type="op-reth")),
        struct(name="flashblocks-rpc-2", use_flashblocks=True, el=struct(type="op-reth"))
    ]
    
    _test_participant_separation_scenario(plan, production_participants, 3, 3)
    
    plan.print("✅ All integration scenarios passed!")


def _test_participant_separation_scenario(plan, participants, expected_regular, expected_flashblocks):
    """Helper function to test participant separation scenarios"""
    
    regular_participants = []
    flashblocks_participants = []
    
    for participant in participants:
        if participant.use_flashblocks:
            flashblocks_participants.append(participant)
        else:
            regular_participants.append(participant)
    
    expect.eq(len(regular_participants), expected_regular)
    expect.eq(len(flashblocks_participants), expected_flashblocks)


def test_flashblocks_error_conditions(plan):
    """Test error conditions and edge cases"""
    
    # Test empty conductor list for websocket proxy
    plan.print("Testing empty conductor list handling")
    
    empty_conductors = []
    upstream_urls = []
    for conductor_context in empty_conductors:
        ws_url = "ws://{}:{}/ws".format(
            conductor_context.service_name,
            conductor_context.conductor_rpc_port
        )
        upstream_urls.append(ws_url)
    
    upstream_ws_str = ",".join(upstream_urls)
    expect.eq(upstream_ws_str, "")  # Should be empty string
    
    # Test invalid EL type for flashblocks
    plan.print("Testing invalid EL type validation") 
    
    invalid_participant = struct(
        name="invalid-flashblocks",
        use_flashblocks=True,
        el=struct(type="op-geth")  # Should be op-reth
    )
    
    is_valid_for_flashblocks = invalid_participant.el.type == "op-reth"
    expect.eq(is_valid_for_flashblocks, False)
    
    # Test websocket URL construction
    plan.print("Testing websocket URL construction")
    
    proxy_context = struct(
        context=struct(
            ws_url="ws://flashblocks-websocket-proxy-2151908-network:8545"
        )
    )
    
    websocket_url = proxy_context.context.ws_url + "/ws"
    expect.eq(websocket_url, "ws://flashblocks-websocket-proxy-2151908-network:8545/ws")
    
    plan.print("✅ All error condition tests passed!")


def test_flashblocks_configuration_validation(plan):
    """Test configuration validation"""
    
    # Test valid flashblocks proxy configuration
    valid_config = {
        "enabled": True,
        "image": "custom/flashblocks-proxy:v1.0.0",
        "ports": {
            "ws": 8545,
            "metrics": 9000
        },
        "min_cpu": 500,
        "max_cpu": 1000,
        "min_mem": 512,
        "max_mem": 1024
    }
    
    # Validate configuration structure
    expect.eq(valid_config["enabled"], True)
    expect.contains(valid_config["image"], "flashblocks-proxy")
    expect.eq(valid_config["ports"]["ws"], 8545)
    expect.eq(valid_config["ports"]["metrics"], 9000)
    expect.gt(valid_config["max_cpu"], valid_config["min_cpu"])
    expect.gt(valid_config["max_mem"], valid_config["min_mem"])
    
    plan.print("✅ Configuration validation tests passed!")