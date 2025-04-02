op_challenger_launcher = import_module(
    "/src/challenger/op-challenger/op_challenger_launcher.star"
)
op_signer_launcher = import_module(
    "/src/signer/op_signer_launcher.star"
)
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
constants = import_module("/src/package_io/constants.star")
util = import_module("/src/util.star")

test_utils = import_module("/test/test_utils.star")

def test_launch_with_defaults(plan):
    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network": "kurtosis-test",
                    },
                    "participants": [
                        {
                            "el_type": "op-reth",
                            "el_image": "op-reth:latest",
                            "cl_type": "op-node",
                            "cl_image": "op-node:latest",
                        }
                    ],
                    "challenger_params": {
                        "enabled": False,
                    },
                }
            ]
        },
    )

    el_context = struct(
        rpc_http_url="rpc_http_url",
    )
    cl_context = struct(
        beacon_http_url="beacon_http_url",
    )
    # el_context, cl_context = launch_test_el_cl(plan, parsed_input_args)

    observability_helper = observability.make_helper(parsed_input_args.observability)

    chains = parsed_input_args.chains
    chain = chains[0]
    
    service_type = op_challenger_launcher.SERVICE_TYPE
    service_name = op_challenger_launcher.SERVICE_NAME
    service_instance_name = util.make_service_instance_name(
        service_name, chain.network_params
    )

    deployment_output = "/path/to/deployment_output"
    l1_config_env_vars = {
        "L1_RPC_URL": "L1_RPC_URL",
        "L1_RPC_KIND": "standard",
        "CL_RPC_URL": "CL_RPC_URL",
    }

    challenger_private_key_mock = "challenger_private_key"
    challenger_address_mock = "challenger_address"

    signer_client = op_signer_launcher.make_client(
        service_type,
        service_instance_name,
    )

    signer_context = struct(
        service=struct(
            hostname=util.make_service_instance_name(
                op_signer_launcher.SERVICE_NAME, chain.network_params
            ),
            ports={
                constants.HTTP_PORT_ID: struct(
                    number=op_signer_launcher.HTTP_PORT_NUM,
                ),
            },
        ),
        ca_artifact="ca_artifact_mock",
        clients={
            service_type: op_signer_launcher.make_populated_client(
                client=signer_client,
                key=challenger_private_key_mock,
                address=challenger_address_mock,
                tls_artifact="tls_artifact_mock",
            )
        },
    )

    dispute_game_factory_address_mock = "dispute_game_factory_address"

    op_challenger_launcher.launch(
        plan=plan,
        el_context=el_context,
        cl_context=cl_context,
        l1_config_env_vars=l1_config_env_vars,
        signer_context=signer_context,
        game_factory_address=dispute_game_factory_address_mock,
        deployment_output=deployment_output,
        network_params=chain.network_params,
        challenger_params=chain.challenger_params,
        interop_params=parsed_input_args.interop,
        observability_helper=observability_helper,
    )

    challenger_service_config = kurtosistest.get_service_config(
        service_instance_name
    )
    expect.ne(challenger_service_config, None)
    expect.eq(challenger_service_config.env_vars, {})
    expect.eq(
        challenger_service_config.entrypoint,
        ["sh", "-c"],
    )

    test_utils.contains_all(
        challenger_service_config.cmd,
        [
            service_name,
            "--cannon-l2-genesis=/network-configs/genesis-2151908.json",
            "--cannon-rollup-config=/network-configs/rollup-2151908.json",
            "--game-factory-address=dispute_game_factory_address",
            "--datadir=/data/op-challenger/op-challenger-data",
            "--l1-beacon=CL_RPC_URL",
            "--l1-eth-rpc=L1_RPC_URL",
            "--l2-eth-rpc=rpc_http_url",
            "--private-key=challenger_private_key",
            "--rollup-rpc=beacon_http_url",
            "--trace-type=cannon,permissioned",
            "--signer.tls.ca=/tls/ca.crt",
            "--signer.tls.cert=/tls/tls.crt",
            "--signer.tls.key=/tls/tls.key",
            "--signer.endpoint=https://op-signer-kurtosis-test:8545",
            "--signer.address=challenger_address",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
            "--cannon-prestates-url=https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon",
        ],
    )
