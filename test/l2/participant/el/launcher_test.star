_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
_input_parser = import_module("/src/package_io/input_parser.star")
_l2_input_parser = import_module("/src/l2/input_parser.star")
_observability = import_module("/src/observability/observability.star")
_registry = import_module("/src/package_io/registry.star")
_util = import_module("/src/util.star")

_el_launcher = import_module("/src/l2/participant/el/launcher.star")

_default_registry = _registry.Registry()
_default_deployment_output = "/deployment.output.json"
_default_jwt_file = "/jwt.file"
_default_l1_config_env_vars = {
    "CL_RPC_URL": "http://l1.cl.rpc",
    "L1_RPC_URL": "http://l1.rpc",
    "L1_WS_URL": "wss://l1.rpc",
    "L1_RPC_KIND": "very.kind",
}
_default_log_level = _ethereum_package_constants.GLOBAL_LOG_LEVEL.info
_default_bootnode_contexts = [
    struct(
        enr="enr:001",
        enode="enode:001",
    )
]


def test_l2_participant_el_launcher_op_besu(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2s_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "el": {
                            "type": "op-besu",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    participant_params = l2_params.participants[0]
    el_params = participant_params.el

    result = _el_launcher.launch(
        plan=plan,
        params=el_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        sequencer_params=None,
        bootnode_contexts=_default_bootnode_contexts,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        observability_helper=observability_helper,
    )

    service = plan.get_service(el_params.service_name)
    service_config = kurtosistest.get_service_config(el_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "besu",
            "--genesis-file=/network-configs/genesis-2151908.json",
            "--network-id=2151908",
            "--data-path=/data/geth/execution-data",
            "--host-allowlist=*",
            "--rpc-http-enabled=true",
            "--rpc-http-host=0.0.0.0",
            "--rpc-http-port=8545",
            "--rpc-http-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3,MINER",
            "--rpc-http-cors-origins=*",
            "--rpc-http-max-active-connections=300",
            "--rpc-ws-enabled=true",
            "--rpc-ws-host=0.0.0.0",
            "--rpc-ws-port=8546",
            "--rpc-ws-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3,MINER",
            "--p2p-enabled=true",
            "--p2p-host=KURTOSIS_IP_ADDR_PLACEHOLDER",
            "--p2p-port=30303",
            "--engine-rpc-enabled=true",
            "--engine-jwt-secret=/jwt/jwtsecret",
            "--engine-host-allowlist=*",
            "--engine-rpc-port=8551",
            "--sync-mode=FULL",
            "--bonsai-limit-trie-logs-enabled=false",
            "--version-compatibility-protection=false",
            "--metrics",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
            "--bootnodes=enode:001",
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "el", "op.network.id": "2151908", "op.el.type": "op-besu"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )


def test_l2_participant_el_launcher_op_erigon(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2s_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "el": {
                            "type": "op-erigon",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    participant_params = l2_params.participants[0]
    el_params = participant_params.el

    sequencer_private_key_mock = "sequencer_private_key"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        sequencer_private_key_mock
    )

    result = _el_launcher.launch(
        plan=plan,
        params=el_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        sequencer_params=None,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        bootnode_contexts=_default_bootnode_contexts,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        observability_helper=observability_helper,
    )

    service = plan.get_service(el_params.service_name)
    service_config = kurtosistest.get_service_config(el_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "erigon init --datadir=/data/op-erigon/execution-data /network-configs/genesis-2151908.json && erigon --datadir=/data/op-erigon/execution-data --networkid=2151908 --http --http.port=8545 --http.addr=0.0.0.0 --http.vhosts=* --http.corsdomain=* --http.api=admin,engine,net,eth,web3,debug,miner --ws --ws.port=8546 --allow-insecure-unlock --authrpc.port=8551 --authrpc.addr=0.0.0.0 --authrpc.vhosts=* --authrpc.jwtsecret=/jwt/jwtsecret --nat=extip:KURTOSIS_IP_ADDR_PLACEHOLDER --rpc.allow-unprotected-txs --port=30303 --metrics --metrics.addr=0.0.0.0 --metrics.port=9001 --bootnodes=enode:001"
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "el", "op.network.id": "2151908", "op.el.type": "op-erigon"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )


def test_l2_participant_el_launcher_op_geth(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2s_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "el": {
                            "type": "op-geth",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    participant_params = l2_params.participants[0]
    el_params = participant_params.el

    sequencer_private_key_mock = "sequencer_private_key"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        sequencer_private_key_mock
    )

    result = _el_launcher.launch(
        plan=plan,
        params=el_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        sequencer_params=None,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        bootnode_contexts=_default_bootnode_contexts,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        observability_helper=observability_helper,
    )

    service = plan.get_service(el_params.service_name)
    service_config = kurtosistest.get_service_config(el_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "geth init --datadir=/data/geth/execution-data --state.scheme=hash /network-configs/genesis-2151908.json && geth --networkid=2151908 --datadir=/data/geth/execution-data --gcmode=archive --state.scheme=hash --http --http.addr=0.0.0.0 --http.vhosts=* --http.corsdomain=* --http.api=admin,engine,net,eth,web3,debug,miner --ws --ws.addr=0.0.0.0 --ws.port=8546 --ws.api=admin,engine,net,eth,web3,debug,miner --ws.origins=* --allow-insecure-unlock --authrpc.port=8551 --authrpc.addr=0.0.0.0 --authrpc.vhosts=* --authrpc.jwtsecret=/jwt/jwtsecret --syncmode=full --nat=extip:KURTOSIS_IP_ADDR_PLACEHOLDER --rpc.allow-unprotected-txs --discovery.port=30303 --port=30303 --metrics --metrics.addr=0.0.0.0 --metrics.port=9001 --bootnodes=enode:001"
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "el", "op.network.id": "2151908", "op.el.type": "op-geth"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )


def test_l2_participant_el_launcher_op_nethermind(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2s_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "el": {
                            "type": "op-nethermind",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    participant_params = l2_params.participants[0]
    el_params = participant_params.el

    sequencer_private_key_mock = "sequencer_private_key"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        sequencer_private_key_mock
    )

    result = _el_launcher.launch(
        plan=plan,
        params=el_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        sequencer_params=None,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        bootnode_contexts=_default_bootnode_contexts,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        observability_helper=observability_helper,
    )

    service = plan.get_service(el_params.service_name)
    service_config = kurtosistest.get_service_config(el_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "--log=debug",
            "--datadir=/data/nethermind/execution-data",
            "--Init.WebSocketsEnabled=true",
            "--JsonRpc.Enabled=true",
            "--JsonRpc.EnabledModules=net,eth,consensus,subscribe,web3,admin,miner",
            "--JsonRpc.Host=0.0.0.0",
            "--JsonRpc.Port=8545",
            "--JsonRpc.WebSocketsPort=8546",
            "--JsonRpc.EngineHost=0.0.0.0",
            "--JsonRpc.EnginePort=8551",
            "--Network.ExternalIp=KURTOSIS_IP_ADDR_PLACEHOLDER",
            "--Network.DiscoveryPort=30303",
            "--Network.P2PPort=30303",
            "--JsonRpc.JwtSecretFile=/jwt/jwtsecret",
            "--Metrics.Enabled=true",
            "--Metrics.ExposeHost=0.0.0.0",
            "--Metrics.ExposePort=9001",
            "--Discovery.Bootnodes=enode:001",
            "--config=none.cfg",
            "--Init.ChainSpecPath=/network-configs/chainspec-2151908.json",
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "el", "op.network.id": "2151908", "op.el.type": "op-nethermind"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )


def test_l2_participant_el_launcher_op_reth(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2s_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "el": {
                            "type": "op-reth",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    participant_params = l2_params.participants[0]
    el_params = participant_params.el

    sequencer_private_key_mock = "sequencer_private_key"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        sequencer_private_key_mock
    )

    result = _el_launcher.launch(
        plan=plan,
        params=el_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        sequencer_params=None,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        bootnode_contexts=_default_bootnode_contexts,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        observability_helper=observability_helper,
    )

    service = plan.get_service(el_params.service_name)
    service_config = kurtosistest.get_service_config(el_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "geth init --datadir=/data/geth/execution-data --state.scheme=hash /network-configs/genesis-2151908.json && geth --networkid=2151908 --datadir=/data/geth/execution-data --gcmode=archive --state.scheme=hash --http --http.addr=0.0.0.0 --http.vhosts=* --http.corsdomain=* --http.api=admin,engine,net,eth,web3,debug,miner --ws --ws.addr=0.0.0.0 --ws.port=8546 --ws.api=admin,engine,net,eth,web3,debug,miner --ws.origins=* --allow-insecure-unlock --authrpc.port=8551 --authrpc.addr=0.0.0.0 --authrpc.vhosts=* --authrpc.jwtsecret=/jwt/jwtsecret --syncmode=full --nat=extip:KURTOSIS_IP_ADDR_PLACEHOLDER --rpc.allow-unprotected-txs --discovery.port=30303 --port=30303 --metrics --metrics.addr=0.0.0.0 --metrics.port=9001 --bootnodes=enode:001"
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "el", "op.network.id": "2151908", "op.el.type": "op-reth"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )
