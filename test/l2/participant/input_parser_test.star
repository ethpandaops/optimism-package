input_parser = import_module("/src/l2/participant/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_id = 1000
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
    "tolerations": [],
    "volume_size": 0,
}


def test_l2_participant_input_parser_empty(plan):
    expect.eq(
        input_parser.parse(None, _default_network_id, _default_registry),
        [],
    )
    expect.eq(
        input_parser.parse({}, _default_network_id, _default_registry),
        [],
    )


def test_l2_participant_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"name": "peter", "extra": None}},
            _default_network_id,
            _default_registry,
        ),
        "Invalid attributes in participant configuration for node0 on network 1000: name,extra",
    )


def test_l2_participant_input_parser_invalid_name(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"node-0": None}, _default_network_id, _default_registry
        ),
        "ID cannot contain '-': node-0",
    )


def test_l2_participant_input_parser_defaults(plan):
    expect.eq(
        input_parser.parse(
            {"node0": None, "node1": {}}, _default_network_id, _default_registry
        ),
        [
            struct(
                cl=struct(
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
                    name="node0",
                    service_name="op-cl-1000-node0-op-node",
                    labels={
                        "op.kind": "cl",
                        "op.network.id": 1000,
                        "op.cl.type": "op-node",
                    },
                    ports={
                        "beacon": _net.port(number=8545),
                    },
                    **_shared_defaults,
                ),
                cl_builder=struct(
                    name="node0",
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
                    service_name="op-cl-1000-node0-op-node",
                    labels={
                        "op.kind": "cl_builder",
                        "op.network.id": 1000,
                        "op.cl.type": "op-node",
                    },
                    ports={
                        "beacon": _net.port(number=8545),
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
                        "op.network.id": 1000,
                        "op.el.type": "op-geth",
                    },
                    ports={
                        "rpc": _net.port(number=8545),
                    },
                    **_shared_defaults,
                ),
                el_builder=struct(
                    name="node0",
                    type="op-geth",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
                    service_name="op-el-1000-node0-op-geth",
                    labels={
                        "op.kind": "el_builder",
                        "op.network.id": 1000,
                        "op.el.type": "op-geth",
                    },
                    ports={
                        "rpc": _net.port(number=8545),
                    },
                    **_shared_defaults,
                ),
            ),
            struct(
                cl=struct(
                    name="node1",
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
                    service_name="op-cl-1000-node1-op-node",
                    labels={
                        "op.kind": "cl",
                        "op.network.id": 1000,
                        "op.cl.type": "op-node",
                    },
                    ports={
                        "beacon": _net.port(number=8545),
                    },
                    **_shared_defaults,
                ),
                cl_builder=struct(
                    name="node1",
                    type="op-node",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
                    service_name="op-cl-1000-node1-op-node",
                    labels={
                        "op.kind": "cl_builder",
                        "op.network.id": 1000,
                        "op.cl.type": "op-node",
                    },
                    ports={
                        "beacon": _net.port(number=8545),
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
                        "op.network.id": 1000,
                        "op.el.type": "op-geth",
                    },
                    ports={
                        "rpc": _net.port(number=8545),
                    },
                    **_shared_defaults,
                ),
                el_builder=struct(
                    name="node1",
                    type="op-geth",
                    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
                    service_name="op-el-1000-node1-op-geth",
                    labels={
                        "op.kind": "el_builder",
                        "op.network.id": 1000,
                        "op.el.type": "op-geth",
                    },
                    ports={
                        "rpc": _net.port(number=8545),
                    },
                    **_shared_defaults,
                ),
            ),
        ],
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
        _default_network_id,
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
