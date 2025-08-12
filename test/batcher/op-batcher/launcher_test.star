_input_parser = import_module("/src/package_io/input_parser.star")
_l2_input_parser = import_module("/src/l2/input_parser.star")
_batcher_input_parser = import_module("/src/batcher/input_parser.star")
_op_batcher_launcher = import_module("/src/batcher/op-batcher/launcher.star")
_observability = import_module("/src/observability/observability.star")
_registry = import_module("/src/package_io/registry.star")
_selectors = import_module("/src/l2/selectors.star")

_default_registry = _registry.Registry()
_default_l1_config_env_vars = {
    "CL_RPC_URL": "http://l1.cl.rpc",
    "L1_RPC_URL": "http://l1.rpc",
    "L1_WS_URL": "wss://l1.rpc",
    "L1_RPC_KIND": "very.kind",
}
_default_network_params = struct(
    network="kurtosis",
    network_id=1000,
    name="network0",
)


def test_batcher_launcher_launch_without_conductor(plan):
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
                    "node0": {"sequencer": True},
                    "node1": {"sequencer": True},
                    "node2": {"sequencer": "node0"},
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    batcher_params = l2_params.batcher_params
    sequencers_params = _selectors.get_sequencers_params(l2_params.participants)

    _op_batcher_launcher.launch(
        plan=plan,
        params=batcher_params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_batcher_private_key="0x0",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        da_server_context=None,
    )

    service_config = kurtosistest.get_service_config(batcher_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "op-batcher",
            "--l2-eth-rpc=http://op-el-2151908-node0-op-geth:8545,http://op-el-2151908-node1-op-geth:8545",
            "--rollup-rpc=http://op-cl-2151908-node0-op-node:8547,http://op-cl-2151908-node1-op-node:8547",
            "--poll-interval=1s",
            "--sub-safety-margin=6",
            "--num-confirmations=1",
            "--safe-abort-nonce-too-low-count=3",
            "--resubmission-timeout=30s",
            "--rpc.addr=0.0.0.0",
            "--rpc.port=8548",
            "--rpc.enable-admin",
            "--max-channel-duration=1",
            "--l1-eth-rpc=http://l1.rpc",
            "--private-key=0x0",
            "--data-availability-type=blobs",
            "--altda.enabled=false",
            "--altda.da-server=",
            "--altda.da-service",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
        ],
    )


def test_batcher_launcher_launch_with_conductor(plan):
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
                    "node0": {"sequencer": True},
                    "node1": {"sequencer": True, "conductor_params": {"enabled": True}},
                    "node2": {"sequencer": "node0"},
                }
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    batcher_params = l2_params.batcher_params
    sequencers_params = _selectors.get_sequencers_params(l2_params.participants)

    _op_batcher_launcher.launch(
        plan=plan,
        params=batcher_params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_batcher_private_key="0x0",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        da_server_context=None,
    )

    service_config = kurtosistest.get_service_config(batcher_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "op-batcher",
            "--l2-eth-rpc=http://op-el-2151908-node0-op-geth:8545,http://op-conductor-2151908-network0-node1:8547",
            "--rollup-rpc=http://op-cl-2151908-node0-op-node:8547,http://op-conductor-2151908-network0-node1:8547",
            "--poll-interval=1s",
            "--sub-safety-margin=6",
            "--num-confirmations=1",
            "--safe-abort-nonce-too-low-count=3",
            "--resubmission-timeout=30s",
            "--rpc.addr=0.0.0.0",
            "--rpc.port=8548",
            "--rpc.enable-admin",
            "--max-channel-duration=1",
            "--l1-eth-rpc=http://l1.rpc",
            "--private-key=0x0",
            "--data-availability-type=blobs",
            "--altda.enabled=false",
            "--altda.da-server=",
            "--altda.da-service",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
        ],
    )
