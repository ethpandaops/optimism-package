_input_parser = import_module("/src/flashblocks/flashblocks-rpc/input_parser.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(network_id=1000, name="my-l2", seconds_per_slot=2)
_default_registry = _registry.Registry()


def test_flashblocks_rpc_input_parser_default_args(plan):
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


def test_flashblocks_rpc_input_parser_custom_registry(plan):
    custom_registry = _registry.Registry(
        {_registry.FLASHBLOCKS_RPC: "custom-registry:latest"}
    )

    parsed = _input_parser.parse(
        {"type": "flashblocks-rpc"},
        _default_network_params,
        custom_registry,
    )

    expect.true(parsed != None)

    expect.eq(parsed.image, "custom-registry:latest")

    expect.eq(parsed.name, "flashblocks-rpc-do-not-use")
    expect.eq(parsed.type, "flashblocks-rpc")


def test_flashblocks_rpc_input_parser_el_parameters_supported(plan):
    """Test that EL parameters are properly supported and passed through"""
    el_params = {
        "type": "flashblocks-rpc",
        "log_level": "debug",
        "max_cpu": 1000,
        "max_mem": 2048,
        "min_cpu": 500,
        "min_mem": 1024,
        "extra_params": ["--custom-flag"],
        "extra_env_vars": {"CUSTOM_VAR": "value"},
        "extra_labels": {"custom.label": "test"},
        "node_selectors": {"node-type": "gpu"},
        "tolerations": [{"key": "gpu", "operator": "Equal", "value": "true"}],
        "volume_size": 100,
    }

    parsed = _input_parser.parse(
        el_params,
        _default_network_params,
        _default_registry,
    )

    expect.true(parsed != None)

    # Verify EL parameters are preserved
    expect.eq(parsed.log_level, "debug")
    expect.eq(parsed.max_cpu, 1000)
    expect.eq(parsed.max_mem, 2048)
    expect.eq(parsed.min_cpu, 500)
    expect.eq(parsed.min_mem, 1024)
    expect.eq(parsed.extra_params, ["--custom-flag"])
    expect.eq(parsed.extra_env_vars, {"CUSTOM_VAR": "value"})
    expect.eq(parsed.extra_labels, {"custom.label": "test"})
    expect.eq(parsed.node_selectors, {"node-type": "gpu"})
    expect.eq(
        parsed.tolerations, [{"key": "gpu", "operator": "Equal", "value": "true"}]
    )
    expect.eq(parsed.volume_size, 100)

    # Verify the service structure is correct
    expect.eq(parsed.name, "flashblocks-rpc-do-not-use")
    expect.eq(parsed.type, "flashblocks-rpc")
    expect.eq(
        parsed.service_name, "op-el-1000-flashblocks-rpc-do-not-use-flashblocks-rpc"
    )
