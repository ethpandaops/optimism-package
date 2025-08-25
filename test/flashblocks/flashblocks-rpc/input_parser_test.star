_input_parser = import_module("/src/flashblocks/flashblocks-rpc/input_parser.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()


def test_flashblocks_rpc_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in flashblocks RPC configuration for network my-l2",
    )


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

    expect.eq(
        _input_parser.parse(
            {"enabled": False},
            _default_network_params,
            _default_registry,
        ),
        None,
    )


def test_flashblocks_rpc_input_parser_enabled_default_args(plan):
    parsed = _input_parser.parse(
        {"enabled": True},
        _default_network_params,
        _default_registry,
    )

    expect.true(parsed != None)

    expect.eq(parsed.name, "flashblocks-rpc-do-not-use")
    expect.eq(parsed.type, "flashblocks-rpc")
    expect.eq(
        parsed.service_name, "op-el-1000-flashblocks-rpc-do-not-use-flashblocks-rpc"
    )

    expect.eq(parsed.labels["op.kind"], "el")
    expect.eq(parsed.labels["op.network.id"], "1000")
    expect.eq(parsed.labels["op.network.participant.index"], "0")
    expect.eq(
        parsed.labels["op.network.participant.name"], "flashblocks-rpc-do-not-use"
    )
    expect.eq(parsed.labels["op.el.type"], "flashblocks-rpc")


def test_flashblocks_rpc_input_parser_custom_params(plan):
    custom_params = {
        "enabled": True,
        "image": "custom-flashblocks-rpc:latest",
        "log_level": "debug",
        "max_cpu": 1000,
        "max_mem": 2048,
    }

    parsed = _input_parser.parse(
        custom_params,
        _default_network_params,
        _default_registry,
    )

    expect.true(parsed != None)

    expect.eq(parsed.image, "custom-flashblocks-rpc:latest")
    expect.eq(parsed.log_level, "debug")
    expect.eq(parsed.max_cpu, 1000)
    expect.eq(parsed.max_mem, 2048)

    expect.eq(parsed.name, "flashblocks-rpc-do-not-use")
    expect.eq(parsed.type, "flashblocks-rpc")
    expect.eq(
        parsed.service_name, "op-el-1000-flashblocks-rpc-do-not-use-flashblocks-rpc"
    )


def test_flashblocks_rpc_input_parser_custom_registry(plan):
    custom_registry = _registry.Registry(
        {_registry.FLASHBLOCKS_RPC: "custom-registry:latest"}
    )

    parsed = _input_parser.parse(
        {"enabled": True},
        _default_network_params,
        custom_registry,
    )

    expect.true(parsed != None)

    expect.eq(parsed.image, "custom-registry:latest")

    expect.eq(parsed.name, "flashblocks-rpc-do-not-use")
    expect.eq(parsed.type, "flashblocks-rpc")
