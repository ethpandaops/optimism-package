_input_parser = import_module("/src/conductor/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(network_id=1000, name="my-l2")
_default_participant_name = "node0"
_default_registry = _registry.Registry()


def test_conductor_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_participant_name,
            _default_registry,
        ),
        "Invalid attributes in conductor configuration for node0 on network my-l2: extra,name",
    )


def test_conductor_input_parser_default_args(plan):
    expect.eq(
        _input_parser.parse(
            None,
            _default_network_params,
            _default_participant_name,
            _default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            {},
            _default_network_params,
            _default_participant_name,
            _default_registry,
        ),
        None,
    )


def test_conductor_input_parser_default_args_enabled(plan):
    _default_params = struct(
        enabled=True,
        extra_params=[],
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-conductor:develop",
        labels={
            "op.kind": "conductor",
            "op.network.id": "1000",
            "op.network.participant.name": "node0",
            "op.conductor.type": "op-conductor",
        },
        ports={
            _net.RPC_PORT_NAME: _net.port(number=8548),
            _net.ADMIN_RPC_PORT_NAME: _net.port(number=8549),
        },
        service_name="op-conductor-1000-my-l2-node0",
    )

    expect.eq(
        _input_parser.parse(
            {
                "enabled": True,
                "image": None,
                "extra_params": None,
            },
            _default_network_params,
            _default_participant_name,
            _default_registry,
        ),
        _default_params,
    )


def test_conductor_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        {
            "enabled": True,
            "image": "op-conductor:brightest",
        },
        _default_network_params,
        _default_participant_name,
        _default_registry,
    )

    expect.eq(
        parsed,
        struct(
            enabled=True,
            extra_params=[],
            image="op-conductor:brightest",
            labels={
                "op.kind": "conductor",
                "op.network.id": "1000",
                "op.network.participant.name": "node0",
                "op.conductor.type": "op-conductor",
            },
            ports={
                _net.RPC_PORT_NAME: _net.port(number=8548),
                _net.ADMIN_RPC_PORT_NAME: _net.port(number=8549),
            },
            service_name="op-conductor-1000-my-l2-node0",
        ),
    )


def test_conductor_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.OP_CONDUCTOR: "conductor:greatest"})

    parsed = _input_parser.parse(
        {"enabled": True},
        _default_network_params,
        _default_participant_name,
        registry,
    )
    expect.eq(parsed.image, "conductor:greatest")

    parsed = _input_parser.parse(
        {"enabled": True, "image": "conductor:oldest"},
        _default_network_params,
        _default_participant_name,
        registry,
    )
    expect.eq(parsed.image, "conductor:oldest")
