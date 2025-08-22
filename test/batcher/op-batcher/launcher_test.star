_input_parser = import_module("/src/package_io/input_parser.star")
_l2_input_parser = import_module("/src/l2/input_parser.star")
_batcher_input_parser = import_module("/src/batcher/input_parser.star")
_op_batcher_launcher = import_module("/src/batcher/op-batcher/launcher.star")
_op_signer_launcher = import_module("/src/signer/op-signer/launcher.star")
_observability = import_module("/src/observability/observability.star")
_registry = import_module("/src/package_io/registry.star")
_selectors = import_module("/src/l2/selectors.star")

_net = import_module("/src/util/net.star")
_util = import_module("/src/util.star")

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
_default_deployment_output = "{}"


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
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_batcher_private_key="0x0",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        signer_context=None,
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
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_batcher_private_key="0x0",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        signer_context=None,
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


def test_batcher_launcher_launch_with_signer(plan):
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
                },
                "signer_params": {
                    "enabled": True,
                },
            }
        },
        registry=_default_registry,
    )

    l2_params = l2s_params[0]
    batcher_params = l2_params.batcher_params
    signer_params = l2_params.signer_params
    sequencers_params = _selectors.get_sequencers_params(l2_params.participants)

    # We create a mock context for the signer since things like its IP, the value references to the uploaded files etc cannot easily be injected
    signer_context = struct(
        service=struct(
            ip_address="7.7.7.7",
            ports={
                _net.HTTP_PORT_NAME: PortSpec(number=8545, application_protocol="http"),
            },
        ),
        credentials=struct(
            ca=struct(crt="ca.crt"),
            hosts={
                batcher_params.service_name: struct(
                    tls=struct(crt="tls.crt", key="tls.key")
                )
            },
        ),
    )

    # We need to mock the batcher address that's being read from the deployment output
    # otherwise we would be getting a random kurtosis runtime value which we cannot get hold of
    batcher_address_mock = "0xbac4e5"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        batcher_address_mock
    )

    _op_batcher_launcher.launch(
        plan=plan,
        params=batcher_params,
        sequencers_params=sequencers_params,
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_batcher_private_key="0x0",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        signer_context=signer_context,
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
            # The signer args start here
            "--signer.tls.ca=ca.crt",
            "--signer.tls.cert=tls.crt",
            "--signer.tls.key=tls.key",
            "--signer.endpoint=http://7.7.7.7:8545",
            "--signer.address={}".format(batcher_address_mock),
            # And end here
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
        ],
    )
