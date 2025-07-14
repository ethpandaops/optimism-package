input_parser = import_module("/src/l2/input_parser.star")
_participant_input_parser = import_module("/src/l2/participant/input_parser.star")
_proxyd_input_parser = import_module("/src/proxyd/input_parser.star")
_proposer_input_parser = import_module("/src/proposer/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_id = 1000
_default_registry = _registry.Registry()


def test_l2_input_parser_empty(plan):
    expect.eq(
        input_parser.parse(None, _default_registry),
        input_parser.parse({"opkurtosis": None}, _default_registry),
    )
    expect.eq(
        input_parser.parse({}, _default_registry),
        input_parser.parse({"opkurtosis": None}, _default_registry),
    )


def test_l2_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"network0": {"name": "peter", "extra": None}},
            _default_registry,
        ),
        "Invalid attributes in L2 configuration for network0: name,extra",
    )


def test_l2_input_parser_invalid_name(plan):
    expect.fails(
        lambda: input_parser.parse({"network_0": None}, _default_registry),
        "L2 name can only contain alphanumeric characters and '-', got 'network_0'",
    )


def test_l2_input_parser_invalid_network_id(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"network0": {"network_params": {"network_id": "x"}}}, _default_registry
        ),
        "L2 ID must be a positive integer in decimal base, got x",
    )

    expect.fails(
        lambda: input_parser.parse(
            {"network0": {"network_params": {"network_id": "0x1"}}}, _default_registry
        ),
        "L2 ID must be a positive integer in decimal base, got ",
    )


def test_l2_input_parser_defaults(plan):
    _default_network_params = struct(
        fjord_time_offset=0,
        fund_dev_accounts=True,
        granite_time_offset=0,
        holocene_time_offset=None,
        interop_time_offset=None,
        isthmus_time_offset=None,
        network="kurtosis",
        network_id=2151908,
        name="network1",
        seconds_per_slot=2,
    )

    _default_batcher_params = struct(
        extra_params=[],
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:v1.14.0",
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8548),
        },
        service_name="op-batcher-2151908-network1",
        labels={
            "op.kind": "batcher",
            "op.network.id": "2151908",
        },
    )

    _default_proposer_params = struct(
        extra_params=[],
        game_type=1,
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:v1.10.0",
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8560),
        },
        proposal_interval="10m",
        service_name="op-proposer-2151908-network1",
        labels={
            "op.kind": "proposer",
            "op.network.id": "2151908",
        },
    )

    _default_proxyd_params = struct(
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd:v4.14.5",
        extra_params=[],
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8080),
        },
        service_name="proxyd-2151908-network1",
        labels={
            "op.kind": "proxyd",
            "op.network.id": "2151908",
        },
        replicas={"node0": "http://op-el-2151908-node0-op-geth:8545"},
    )

    _default_participants = _participant_input_parser.parse(
        {"node0": None}, _default_network_params, _default_registry
    )

    expect.eq(
        input_parser.parse({"network1": None}, _default_registry),
        [
            struct(
                network_params=_default_network_params,
                participants=_default_participants,
                batcher_params=_default_batcher_params,
                proposer_params=_default_proposer_params,
                proxyd_params=_default_proxyd_params,
                # DA is disabled by default
                da_params=None,
                # tx fuzzer is disabled by default
                tx_fuzzer_params=None,
                # Blockscout is disabled by default
                blockscout_params=None,
            )
        ],
    )

    participants = {"node0": {}, "node1": None}
    parsed_participants = _participant_input_parser.parse(
        participants, _default_network_params, _default_registry
    )

    parsed_proxyd_params = _proxyd_input_parser.parse(
        proxyd_args=None,
        network_params=_default_network_params,
        participants_params=parsed_participants,
        registry=_default_registry,
    )

    expect.eq(
        input_parser.parse(
            {"network1": {"participants": participants}}, _default_registry
        ),
        [
            struct(
                network_params=_default_network_params,
                participants=parsed_participants,
                batcher_params=_default_batcher_params,
                proposer_params=_default_proposer_params,
                proxyd_params=parsed_proxyd_params,
                # DA is disabled by default
                da_params=None,
                # tx fuzzer is disabled by default
                tx_fuzzer_params=None,
                # Blockscout is disabled by default
                blockscout_params=None,
            )
        ],
    )


def test_l2_input_parser_da_defaults(plan):
    _default_da_params = struct(
        enabled=True,
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/da-server:latest",
        cmd=[
            "da-server",
            "--file.path=/home",
            "--addr=0.0.0.0",
            "--port={}".format(3100),
            "--log.level=debug",
        ],
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=3100),
        },
        service_name="op-da-da-server-2151908-network1",
        labels={
            "op.kind": "da",
            "op.network.id": "2151908",
            "op.da.type": "da-server",
        },
    )

    parsed = input_parser.parse(
        {"network1": {"participants": {"node0": {}}, "da_params": {"enabled": True}}},
        _default_registry,
    )
    expect.eq(parsed[0].da_params, _default_da_params)


def test_l2_input_parser_tz_fuzzer_defaults(plan):
    _default_tx_fuzzer_params = struct(
        enabled=True,
        extra_params=[],
        image="ethpandaops/tx-fuzz:master",
        labels={"op.kind": "tx-fuzzer", "op.network.id": "2151908"},
        max_cpu=1000,
        max_memory=300,
        min_cpu=100,
        min_memory=20,
        service_name="op-tx-fuzzer-2151908-network1",
    )

    parsed = input_parser.parse(
        {
            "network1": {
                "participants": {"node0": {}},
                "tx_fuzzer_params": {"enabled": True},
            }
        },
        _default_registry,
    )
    expect.eq(parsed[0].tx_fuzzer_params, _default_tx_fuzzer_params)


def test_l2_input_parser_auto_network_id(plan):
    parsed = input_parser.parse(
        {"network0": None, "network1": None, "network2": None}, _default_registry
    )

    expect.eq(parsed[0].network_params.network_id, 2151908)
    expect.eq(parsed[1].network_params.network_id, 2151909)
    expect.eq(parsed[2].network_params.network_id, 2151910)

    parsed = input_parser.parse(
        {
            "network0": None,
            "network1": {
                "network_params": {"network_id": 7},
                "participants": {"node0": None},
            },
            "network2": None,
        },
        _default_registry,
    )

    expect.eq(parsed[0].network_params.network_id, 2151908)
    expect.eq(parsed[1].network_params.network_id, 7)
    expect.eq(parsed[2].network_params.network_id, 2151909)

    expect.fails(
        lambda: input_parser.parse(
            {
                "network0": None,
                "network1": {
                    "network_params": {"network_id": 2151908},
                    "participants": {"node0": None},
                },
                "network2": None,
            },
            _default_registry,
        ),
        "L2 IDs must be unique, got duplicates: 2151908",
    )
