_input_parser = import_module("/src/mev/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(network_id=1000, name="my-l2")
_default_participant_index = 0
_default_participant_name = "node0"
_default_registry = _registry.Registry()


def test_mev_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            mev_args={"extra": None, "name": "x"},
            network_params=_default_network_params,
            participant_index=_default_participant_index,
            participant_name=_default_participant_name,
            registry=_default_registry,
        ),
        "Invalid attributes in MEV configuration for node0 on network my-l2: extra,name",
    )


def test_mev_input_parser_invalid_builder_params(plan):
    expect.fails(
        lambda: _input_parser.parse(
            mev_args={"enabled": True, "builder_port": "7"},
            network_params=_default_network_params,
            participant_index=_default_participant_index,
            participant_name=_default_participant_name,
            registry=_default_registry,
        ),
        "Missing builder_host in MEV configuration for node0 on network my-l2",
    )

    expect.fails(
        lambda: _input_parser.parse(
            mev_args={"enabled": True, "builder_host": "localhost"},
            network_params=_default_network_params,
            participant_index=_default_participant_index,
            participant_name=_default_participant_name,
            registry=_default_registry,
        ),
        "Missing builder_port in MEV configuration for node0 on network my-l2",
    )


def test_mev_input_parser_default_args(plan):
    _default_params = struct(
        enabled=True,
        image="flashbots/rollup-boost:latest",
        type="rollup-boost",
        builder_host=None,
        builder_port=None,
        service_name="op-mev-rollup-boost-1000-my-l2-node0",
        labels={
            "op.kind": "mev",
            "op.network.id": "1000",
            "op.network.participant.index": "0",
            "op.network.participant.name": "node0",
            "op.mev.type": "rollup-boost",
        },
        ports={
            _net.RPC_PORT_NAME: _net.port(number=8541),
        },
    )

    expect.eq(
        _input_parser.parse(
            mev_args=None,
            network_params=_default_network_params,
            participant_index=_default_participant_index,
            participant_name=_default_participant_name,
            registry=_default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            mev_args={},
            network_params=_default_network_params,
            participant_index=_default_participant_index,
            participant_name=_default_participant_name,
            registry=_default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            {"enabled": False},
            _default_network_params,
            _default_participant_name,
            _default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            mev_args={
                "enabled": True,
                "image": None,
                "type": None,
                "builder_host": None,
                "builder_port": None,
            },
            network_params=_default_network_params,
            participant_index=_default_participant_index,
            participant_name=_default_participant_name,
            registry=_default_registry,
        ),
        _default_params,
    )


def test_mev_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        mev_args={
            "enabled": True,
            "image": "op-rollup-boost:brightest",
            "builder_host": "localhost",
            "builder_port": 8080,
        },
        network_params=_default_network_params,
        participant_index=_default_participant_index,
        participant_name=_default_participant_name,
        registry=_default_registry,
    )

    expect.eq(
        parsed,
        struct(
            enabled=True,
            image="op-rollup-boost:brightest",
            type="rollup-boost",
            builder_host="localhost",
            builder_port=8080,
            service_name="op-mev-rollup-boost-1000-my-l2-node0",
            labels={
                "op.kind": "mev",
                "op.network.id": "1000",
                "op.network.participant.index": "0",
                "op.network.participant.name": "node0",
                "op.mev.type": "rollup-boost",
            },
            ports={
                _net.RPC_PORT_NAME: _net.port(number=8541),
            },
        ),
    )


def test_mev_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.ROLLUP_BOOST: "rollup-boost:greatest"})

    parsed = _input_parser.parse(
        mev_args={"enabled": True},
        network_params=_default_network_params,
        participant_index=_default_participant_index,
        participant_name=_default_participant_name,
        registry=registry,
    )
    expect.eq(parsed.image, "rollup-boost:greatest")

    parsed = _input_parser.parse(
        mev_args={"enabled": True, "image": "rollup-boost:oldest"},
        network_params=_default_network_params,
        participant_index=_default_participant_index,
        participant_name=_default_participant_name,
        registry=registry,
    )
    expect.eq(parsed.image, "rollup-boost:oldest")
