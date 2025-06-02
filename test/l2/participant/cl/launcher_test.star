_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
_input_parser = import_module("/src/package_io/input_parser.star")
_l2_input_parser = import_module("/src/l2/input_parser.star")
_observability = import_module("/src/observability/observability.star")
_registry = import_module("/src/package_io/registry.star")
_util = import_module("/src/util.star")

_cl_launcher = import_module("/src/l2/participant/cl/launcher.star")

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
_default_el_context = struct(
    ip_addr="0.0.0.0",
    engine_rpc_port_num=8888,
    rpc_port_num=9999,
)
_default_cl_contexts = [struct(enr="enr.001"), struct(enr="enr.002")]


def test_l2_participant_cl_launcher_hildr(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "cl": {
                            "type": "hildr",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    participant_params = l2_params.participants[0]
    cl_params = participant_params.cl

    result = _cl_launcher.launch(
        plan=plan,
        params=cl_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        da_params=l2_params.da_params,
        is_sequencer=True,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        el_context=_default_el_context,
        cl_contexts=_default_cl_contexts,
        observability_helper=observability_helper,
    )

    service = plan.get_service(cl_params.service_name)
    service_config = kurtosistest.get_service_config(cl_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "--devnet",
            "--log-level=INFO",
            "--jwt-file=/jwt/jwtsecret",
            "--l1-beacon-url=http://l1.cl.rpc",
            "--l1-rpc-url=http://l1.rpc",
            "--l1-ws-rpc-url=wss://l1.rpc",
            "--l2-engine-url=http://0.0.0.0:8888",
            "--l2-rpc-url=http://0.0.0.0:9999",
            "--rpc-addr=0.0.0.0",
            "--rpc-port=8547",
            "--sync-mode=full",
            "--network=/network-configs/rollup-2151908.json",
            "--metrics-enable",
            "--metrics-port=9001",
            "--sequencer-enable",
            "--disc-boot-nodes=enr.001,enr.002",
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "cl", "op.network.id": "2151908", "op.cl.type": "hildr"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )


def test_l2_participant_cl_launcher_kona_node(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "cl": {
                            "type": "hildr",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    participant_params = l2_params.participants[0]
    cl_params = participant_params.cl

    sequencer_private_key_mock = "sequencer_private_key"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        sequencer_private_key_mock
    )

    result = _cl_launcher.launch(
        plan=plan,
        params=cl_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        da_params=l2_params.da_params,
        is_sequencer=True,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        el_context=_default_el_context,
        cl_contexts=_default_cl_contexts,
        observability_helper=observability_helper,
    )

    service = plan.get_service(cl_params.service_name)
    service_config = kurtosistest.get_service_config(cl_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "--l2-chain-id",
            "2151908",
            "-vvv",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
            "node",
            "--l1-eth-rpc",
            "http://l1.rpc",
            "--l1-beacon",
            "http://l1.cl.rpc",
            "--l2-engine-rpc",
            "http://0.0.0.0:8888",
            "--l2-engine-jwt-secret",
            "/jwt/jwtsecret",
            "--l2-provider-rpc",
            "http://0.0.0.0:8888",
            "--l2-config-file",
            "/network-configs/rollup-2151908.json",
            "--p2p.advertise.ip",
            "KURTOSIS_IP_ADDR_PLACEHOLDER",
            "--p2p.advertise.tcp",
            "9003",
            "--p2p.advertise.udp",
            "9003",
            "--p2p.listen.ip",
            "0.0.0.0",
            "--p2p.listen.tcp",
            "9003",
            "--p2p.listen.udp",
            "9003",
            "--rpc.addr",
            "0.0.0.0",
            "--rpc.port",
            "8547",
            "--rpc.enable-admin",
            "--metrics.enabled=true",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
            "--p2p.sequencer.key={}".format(sequencer_private_key_mock),
            "--sequencer.enabled",
            "--sequencer.l1-confs=2",
            "--p2p.bootnodes",
            "enr.001,enr.002",
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "cl", "op.network.id": "2151908", "op.cl.type": "kona-node"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )


def test_l2_participant_cl_launcher_op_node(plan):
    # We'll need the observability params from the legacy parser
    legacy_params = _input_parser.input_parser(
        plan=plan,
        input_args={},
    )
    observability_helper = _observability.make_helper(legacy_params.observability)

    l2_params = _l2_input_parser.parse(
        {
            "network0": {
                "participants": {
                    "node0": {
                        "cl": {
                            "type": "hildr",
                        }
                    }
                }
            }
        },
        registry=_default_registry,
    )

    participant_params = l2_params.participants[0]
    cl_params = participant_params.cl

    sequencer_private_key_mock = "sequencer_private_key"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        sequencer_private_key_mock
    )

    result = _cl_launcher.launch(
        plan=plan,
        params=cl_params,
        network_params=l2_params.network_params,
        supervisors_params=[],
        da_params=l2_params.da_params,
        is_sequencer=True,
        jwt_file=_default_jwt_file,
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        log_level=_default_log_level,
        persistent=True,
        tolerations=[],
        node_selectors={},
        el_context=_default_el_context,
        cl_contexts=_default_cl_contexts,
        observability_helper=observability_helper,
    )

    service = plan.get_service(cl_params.service_name)
    service_config = kurtosistest.get_service_config(cl_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "op-node",
            "--log.level=INFO",
            "--l2=http://0.0.0.0:8888",
            "--l2.jwt-secret=/jwt/jwtsecret",
            "--verifier.l1-confs=1",
            "--rollup.config=/network-configs/rollup-2151908.json",
            "--rpc.addr=0.0.0.0",
            "--rpc.port=8547",
            "--rpc.enable-admin",
            "--l1=http://l1.rpc",
            "--l1.rpckind=very.kind",
            "--l1.beacon=http://l1.cl.rpc",
            "--p2p.advertise.ip=KURTOSIS_IP_ADDR_PLACEHOLDER",
            "--p2p.advertise.tcp=9003",
            "--p2p.advertise.udp=9003",
            "--p2p.listen.ip=0.0.0.0",
            "--p2p.listen.tcp=9003",
            "--p2p.listen.udp=9003",
            "--safedb.path=/data/op-node/op-node-beacon-data",
            "--altda.enabled=false",
            "--altda.da-server=",
            "--metrics.enabled=true",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
            "--p2p.sequencer.key={}".format(sequencer_private_key_mock),
            "--sequencer.enabled",
            "--sequencer.l1-confs=2",
            "--p2p.bootnodes=enr.001,enr.002",
        ],
    )
    expect.eq(
        service_config.labels,
        {"op.kind": "cl", "op.network.id": "2151908", "op.cl.type": "op-node"},
    )
    expect.eq(
        service_config.files["/network-configs"].artifact_names,
        [_default_deployment_output],
    )
    expect.eq(
        service_config.files["/jwt"].artifact_names,
        [_default_jwt_file],
    )
