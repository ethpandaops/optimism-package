_input_parser = import_module("/src/package_io/input_parser.star")
_l2_input_parser = import_module("/src/l2/input_parser.star")
_proposer_input_parser = import_module("/src/proposer/input_parser.star")
_op_proposer_launcher = import_module("/src/proposer/op-proposer/launcher.star")
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


def test_proposer_launcher_launch_without_signer(plan):
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
    proposer_params = l2_params.proposer_params
    sequencers_params = _selectors.get_sequencers_params(l2_params.participants)

    # plan,
    # params,
    # sequencers_params,
    # l1_config_env_vars,
    # gs_proposer_private_key,
    # game_factory_address,
    # network_params,
    # observability_helper,
    # signer_context,

    _op_proposer_launcher.launch(
        plan=plan,
        params=proposer_params,
        sequencers_params=sequencers_params,
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_proposer_private_key="0x0",
        game_factory_address="0x1",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        signer_context=None,
    )

    service_config = kurtosistest.get_service_config(proposer_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "op-proposer",
            "--poll-interval=12s",
            "--rpc.port=8560",
            "--rollup-rpc=http://op-cl-2151908-node0-op-node:8547,http://op-cl-2151908-node1-op-node:8547",
            "--game-factory-address=0x1",
            "--private-key=0x0",
            "--l1-eth-rpc=http://l1.rpc",
            "--allow-non-finalized=true",
            "--game-type=1",
            "--proposal-interval=10m",
            "--wait-node-sync=true",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
        ],
    )


def test_proposer_launcher_launch_with_signer(plan):
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
    proposer_params = l2_params.proposer_params
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
                proposer_params.service_name: struct(
                    tls=struct(crt="tls.crt", key="tls.key")
                )
            },
        ),
    )

    # We need to mock the proposer address that's being read from the deployment output
    # otherwise we would be getting a random kurtosis runtime value which we cannot get hold of
    proposer_address_mock = "0xbac4e5"
    kurtosistest.mock(_util, "read_network_config_value").mock_return_value(
        proposer_address_mock
    )

    _op_proposer_launcher.launch(
        plan=plan,
        params=proposer_params,
        sequencers_params=sequencers_params,
        deployment_output=_default_deployment_output,
        l1_config_env_vars=_default_l1_config_env_vars,
        gs_proposer_private_key="0x0",
        game_factory_address="0x1",
        network_params=_default_network_params,
        observability_helper=observability_helper,
        signer_context=signer_context,
    )

    service_config = kurtosistest.get_service_config(proposer_params.service_name)

    expect.eq(
        service_config.cmd,
        [
            "op-proposer",
            "--poll-interval=12s",
            "--rpc.port=8560",
            "--rollup-rpc=http://op-cl-2151908-node0-op-node:8547,http://op-cl-2151908-node1-op-node:8547",
            "--game-factory-address=0x1",
            "--private-key=0x0",
            "--l1-eth-rpc=http://l1.rpc",
            "--allow-non-finalized=true",
            "--game-type=1",
            "--proposal-interval=10m",
            "--wait-node-sync=true",
            "--signer.tls.ca=ca.crt",
            "--signer.tls.cert=tls.crt",
            "--signer.tls.key=tls.key",
            "--signer.endpoint=http://7.7.7.7:8545",
            "--signer.address=0xbac4e5",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
        ],
    )
