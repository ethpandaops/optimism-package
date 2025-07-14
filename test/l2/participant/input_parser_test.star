input_parser = import_module("/src/l2/participant/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(
    network_id=1000,
    name="my-l2",
)
_default_registry = _registry.Registry()

_shared_defaults = {
    "extra_env_vars": {},
    "extra_labels": {},
    "extra_params": [],
    "log_level": None,
    "max_cpu": 0,
    "max_mem": 0,
    "min_cpu": 0,
    "min_mem": 0,
    "node_selectors": {},
    "tolerations": [],
    "volume_size": 0,
}


def test_l2_participant_input_parser_empty(plan):
    expect.fails(
        lambda: input_parser.parse(None, _default_network_params, _default_registry),
        "Invalid participants configuration for network my-l2: at least one participant must be defined",
    )

    expect.fails(
        lambda: input_parser.parse({}, _default_network_params, _default_registry),
        "Invalid participants configuration for network my-l2: at least one participant must be defined",
    )


def test_l2_participant_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"name": "peter", "extra": None}},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in participant configuration for node0 on network my-l2: name,extra",
    )


def test_l2_participant_input_parser_invalid_name(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"node_0": None}, _default_network_params, _default_registry
        ),
        "Name of the node on network my-l2 can only contain alphanumeric characters and '-', got 'node_0'",
    )


def test_l2_participant_input_parser_defaults(plan):
    expect.eq(
        input_parser.parse(
            {"node0": None, "node1": {}}, _default_network_params, _default_registry
        ),
        [
            struct(
                name="node0",
                sequencer="node0",
                cl=struct(
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.13.4",
                    name="node0",
                    service_name="op-cl-1000-node0-op-node",
                    labels={
                        "op.kind": "cl",
                        "op.network.id": "1000",
                        "op.network.participant.index": "0",
                        "op.network.participant.name": "node0",
                        "op.cl.type": "op-node",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8547),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=9003),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=9003, transport_protocol="UDP"
                        ),
                    },
                    **_shared_defaults,
                ),
                cl_builder=struct(
                    name="node0",
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.13.4",
                    service_name="op-clbuilder-1000-node0-op-node",
                    labels={
                        "op.kind": "clbuilder",
                        "op.network.id": "1000",
                        "op.network.participant.index": "0",
                        "op.network.participant.name": "node0",
                        "op.cl.type": "op-node",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8547),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=9003),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=9003, transport_protocol="UDP"
                        ),
                    },
                    **_shared_defaults,
                ),
                el=struct(
                    name="node0",
                    type="op-geth",
                    service_name="op-el-1000-node0-op-geth",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
                    labels={
                        "op.kind": "el",
                        "op.network.id": "1000",
                        "op.network.participant.index": "0",
                        "op.network.participant.name": "node0",
                        "op.el.type": "op-geth",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8545),
                        _net.WS_PORT_NAME: _net.port(number=8546),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=30303),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=30303, transport_protocol="UDP"
                        ),
                        _net.ENGINE_RPC_PORT_NAME: _net.port(number=8551),
                    },
                    **_shared_defaults,
                ),
                el_builder=struct(
                    name="node0",
                    type="op-geth",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
                    service_name="op-elbuilder-1000-node0-op-geth",
                    labels={
                        "op.kind": "elbuilder",
                        "op.network.id": "1000",
                        "op.network.participant.index": "0",
                        "op.network.participant.name": "node0",
                        "op.el.type": "op-geth",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8545),
                        _net.WS_PORT_NAME: _net.port(number=8546),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=30303),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=30303, transport_protocol="UDP"
                        ),
                        _net.ENGINE_RPC_PORT_NAME: _net.port(number=8551),
                    },
                    key=None,
                    **_shared_defaults,
                ),
                mev_params=None,
                conductor_params=None,
            ),
            struct(
                name="node1",
                sequencer="node0",
                cl=struct(
                    name="node1",
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.13.4",
                    service_name="op-cl-1000-node1-op-node",
                    labels={
                        "op.kind": "cl",
                        "op.network.id": "1000",
                        "op.network.participant.index": "1",
                        "op.network.participant.name": "node1",
                        "op.cl.type": "op-node",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8547),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=9003),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=9003, transport_protocol="UDP"
                        ),
                    },
                    **_shared_defaults,
                ),
                cl_builder=struct(
                    name="node1",
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.13.4",
                    service_name="op-clbuilder-1000-node1-op-node",
                    labels={
                        "op.kind": "clbuilder",
                        "op.network.id": "1000",
                        "op.network.participant.index": "1",
                        "op.network.participant.name": "node1",
                        "op.cl.type": "op-node",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8547),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=9003),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=9003, transport_protocol="UDP"
                        ),
                    },
                    **_shared_defaults,
                ),
                el=struct(
                    name="node1",
                    type="op-geth",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
                    service_name="op-el-1000-node1-op-geth",
                    labels={
                        "op.kind": "el",
                        "op.network.id": "1000",
                        "op.network.participant.index": "1",
                        "op.network.participant.name": "node1",
                        "op.el.type": "op-geth",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8545),
                        _net.WS_PORT_NAME: _net.port(number=8546),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=30303),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=30303, transport_protocol="UDP"
                        ),
                        _net.ENGINE_RPC_PORT_NAME: _net.port(number=8551),
                    },
                    **_shared_defaults,
                ),
                el_builder=struct(
                    name="node1",
                    type="op-geth",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
                    service_name="op-elbuilder-1000-node1-op-geth",
                    labels={
                        "op.kind": "elbuilder",
                        "op.network.id": "1000",
                        "op.network.participant.index": "1",
                        "op.network.participant.name": "node1",
                        "op.el.type": "op-geth",
                    },
                    ports={
                        _net.RPC_PORT_NAME: _net.port(number=8545),
                        _net.WS_PORT_NAME: _net.port(number=8546),
                        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=30303),
                        _net.UDP_DISCOVERY_PORT_NAME: _net.port(
                            number=30303, transport_protocol="UDP"
                        ),
                        _net.ENGINE_RPC_PORT_NAME: _net.port(number=8551),
                    },
                    key=None,
                    **_shared_defaults,
                ),
                mev_params=None,
                conductor_params=None,
            ),
        ],
    )


def test_l2_participant_input_parser_el_builder_key(plan):
    parsed = input_parser.parse(
        {"node0": {"el_builder": {"key": "secret key"}}},
        _default_network_params,
        _default_registry,
    )

    expect.eq(parsed[0].el_builder.key, "secret key")

    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"el": {"key": "secret key"}}},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in EL configuration for node0 on network my-l2: key",
    )


def test_l2_participant_input_parser_defaults_conductor_enabled(plan):
    parsed = input_parser.parse(
        {"node0": {"conductor_params": {"enabled": True}}, "node1": {}},
        _default_network_params,
        _default_registry,
    )
    expect.eq(
        parsed[0].conductor_params,
        struct(
            enabled=True,
            extra_params=[],
            image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-conductor:v0.7.1",
            labels={
                "op.kind": "conductor",
                "op.network.id": "1000",
                "op.network.participant.index": "0",
                "op.network.participant.name": "node0",
                "op.conductor.type": "op-conductor",
            },
            ports={
                _net.RPC_PORT_NAME: _net.port(number=8547),
                _net.CONSENSUS_PORT_NAME: _net.port(number=50050),
            },
            service_name="op-conductor-1000-my-l2-node0",
            admin=True,
            proxy=True,
            paused=False,
            bootstrap=False,
        ),
    )


def test_l2_participant_input_parser_defaults_conductor_enabled_insufficient_peers(
    plan,
):
    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"conductor_params": {"enabled": True}}},
            _default_network_params,
            _default_registry,
        ),
        "Invalid participants configuration for network my-l2: at least two participants must be defined if conductors are present",
    )


def test_l2_participant_input_parser_invalid_sequencers(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"sequencer": "nodeNada"}, "node1": {"sequencer": True}},
            _default_network_params,
            _default_registry,
        ),
        "Invalid sequencer value for participant node0 on network my-l2: participant nodeNada does not exist",
    )

    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"sequencer": 7}}, _default_network_params, _default_registry
        ),
        "Invalid sequencer value for participant node0 on network my-l2: expected string or bool, got int 7",
    )

    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"sequencer": False}}, _default_network_params, _default_registry
        ),
        "Invalid sequencer configuration for network my-l2: could not find at least one sequencer",
    )

    expect.fails(
        lambda: input_parser.parse(
            {
                "node0": {
                    "sequencer": True,
                },
                "node1": {
                    "sequencer": False,
                },
                "node2": {"sequencer": "node1"},
            },
            _default_network_params,
            _default_registry,
        ),
        "Invalid sequencer value for participant node2 on network my-l2: participant node1 is not a sequencer",
    )

    expect.fails(
        lambda: input_parser.parse(
            {
                "node0": {
                    "sequencer": True,
                },
                "node1": {
                    "sequencer": False,
                },
                "node2": {"sequencer": None},
                "node3": {},
            },
            _default_network_params,
            _default_registry,
        ),
        "Invalid participants configuration on network my-l2: sequencers explicitly defined for nodes node0,node1 but left implicit for node2,node3.",
    )


def test_l2_participant_input_parser_explicit_sequencers(plan):
    parsed = input_parser.parse(
        {
            "node0": {
                # The first node is a sequencer explicitly
                "sequencer": True
            },
            "node1": {
                # The second node is not a sequencer explicitly
                "sequencer": False
            },
            "node2": {
                # The third node is not a sequencer explicitly
                "sequencer": False
            },
            "node3": {
                # The fourth node is not a sequencer explicitly
                "sequencer": False
            },
            "node4": {
                # The fifth node refers to a sequencer explicitly
                "sequencer": "node0"
            },
        },
        _default_network_params,
        _default_registry,
    )

    parsed_sequencers = {p.name: p.sequencer for p in parsed}
    expect.eq(
        parsed_sequencers,
        {
            "node0": "node0",
            "node1": "node0",
            "node2": "node0",
            "node3": "node0",
            "node4": "node0",
        },
    )

    # Now we test with multiple sequencers to see whether the assignment works
    parsed = input_parser.parse(
        {
            "node0": {"sequencer": True},
            "node1": {"sequencer": True},
            "node2": {"sequencer": True},
            "node3": {"sequencer": False},
            "node4": {"sequencer": False},
            "node5": {"sequencer": "node2"},
            "node6": {"sequencer": False},
            "node7": {"sequencer": False},
            "node8": {"sequencer": False},
            "node9": {"sequencer": False},
        },
        _default_network_params,
        _default_registry,
    )

    parsed_sequencers = {p.name: p.sequencer for p in parsed}
    expect.eq(
        parsed_sequencers,
        {
            "node0": "node0",
            "node1": "node1",
            "node2": "node2",
            "node3": "node0",
            "node4": "node0",
            "node5": "node2",
            "node6": "node0",
            "node7": "node0",
            "node8": "node0",
            "node9": "node0",
        },
    )

    # Now we test with sequencer value pointing to self
    parsed = input_parser.parse(
        {
            "node0": {"sequencer": "node0"},
            "node1": {"sequencer": "node1"},
            "node2": {"sequencer": "node2"},
            "node3": {"sequencer": False},
            "node4": {"sequencer": False},
            "node5": {"sequencer": "node2"},
            "node6": {"sequencer": False},
            "node7": {"sequencer": False},
            "node8": {"sequencer": False},
            "node9": {"sequencer": False},
        },
        _default_network_params,
        _default_registry,
    )

    parsed_sequencers = {p.name: p.sequencer for p in parsed}
    expect.eq(
        parsed_sequencers,
        {
            "node0": "node0",
            "node1": "node1",
            "node2": "node2",
            "node3": "node0",
            "node4": "node0",
            "node5": "node2",
            "node6": "node0",
            "node7": "node0",
            "node8": "node0",
            "node9": "node0",
        },
    )


def test_l2_participant_input_parser_custom_registry(plan):
    registry = _registry.Registry(
        {
            _registry.OP_GETH: "op-geth:greatest",
            _registry.OP_RETH: "op-reth:slightest",
            _registry.OP_BESU: "op-besu:roundest",
            _registry.OP_ERIGON: "op-erigon:longest",
            _registry.OP_NETHERMIND: "op-nethermind:sunniest",
            _registry.OP_NODE: "op-node:smallest",
            _registry.KONA_NODE: "kona-node:widest",
            _registry.HILDR: "hildr:shortest",
        }
    )

    parsed = input_parser.parse(
        {
            "node0": {"el": {"type": "op-geth"}, "cl": {"type": "op-node"}},
            "node1": {
                "el_builder": {"type": "op-geth"},
                "cl_builder": {"type": "op-node"},
            },
            "node2": {"el": {"type": "op-reth"}, "cl": {"type": "hildr"}},
            "node3": {
                "el_builder": {"type": "op-reth"},
                "cl_builder": {"type": "hildr"},
            },
            "node4": {"el": {"type": "op-besu"}, "cl": {"type": "kona-node"}},
            "node5": {
                "el_builder": {"type": "op-besu"},
                "cl_builder": {"type": "kona-node"},
            },
            "node6": {"el": {"type": "op-erigon"}},
            "node7": {"el_builder": {"type": "op-erigon"}},
            "node8": {"el": {"type": "op-nethermind"}},
            "node9": {"el_builder": {"type": "op-nethermind"}},
            "node10": {
                "el": {"image": "op-geth:edge"},
                "cl": {"image": "op-node:edge"},
            },
            "node11": {
                "el_builder": {"image": "op-geth:edge"},
                "cl_builder": {"image": "op-node:edge"},
            },
        },
        _default_network_params,
        registry,
    )

    # node0
    node0 = parsed[0]
    expect.eq(node0.el.image, "op-geth:greatest")
    expect.eq(node0.cl.image, "op-node:smallest")

    # node1
    node1 = parsed[1]
    expect.eq(node1.el_builder.image, "op-geth:greatest")
    expect.eq(node1.cl_builder.image, "op-node:smallest")

    # node2
    node2 = parsed[2]
    expect.eq(node2.el.image, "op-reth:slightest")
    expect.eq(node2.cl.image, "hildr:shortest")

    # node3
    node3 = parsed[3]
    expect.eq(node3.el_builder.image, "op-reth:slightest")
    expect.eq(node3.cl_builder.image, "hildr:shortest")

    # node4
    node4 = parsed[4]
    expect.eq(node4.el.image, "op-besu:roundest")
    expect.eq(node4.cl.image, "kona-node:widest")

    # node5
    node5 = parsed[5]
    expect.eq(node5.el_builder.image, "op-besu:roundest")
    expect.eq(node5.cl_builder.image, "kona-node:widest")

    # node6
    node6 = parsed[6]
    expect.eq(node6.el.image, "op-erigon:longest")

    # node7
    node7 = parsed[7]
    expect.eq(node7.el_builder.image, "op-erigon:longest")

    # node8
    node8 = parsed[8]
    expect.eq(node8.el.image, "op-nethermind:sunniest")

    # node9
    node9 = parsed[9]
    expect.eq(node9.el_builder.image, "op-nethermind:sunniest")

    # node10
    node10 = parsed[10]
    expect.eq(node10.el.image, "op-geth:edge")
    expect.eq(node10.cl.image, "op-node:edge")

    # node11
    node11 = parsed[11]
    expect.eq(node11.el_builder.image, "op-geth:edge")
    expect.eq(node11.cl_builder.image, "op-node:edge")
