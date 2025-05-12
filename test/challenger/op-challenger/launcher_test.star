op_challenger_launcher = import_module("/src/challenger/op-challenger/launcher.star")
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
util = import_module("/src/util.star")


def test_op_challenger_launch_with_defaults(plan):
    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": 1000,
                    },
                    "participants": [
                        {
                            "el_type": "op-reth",
                            "el_image": "op-reth:latest",
                            "cl_type": "op-node",
                            "cl_image": "op-node:latest",
                        }
                    ],
                }
            ],
            "challengers": {"challenger": None},
        },
    )

    observability_helper = observability.make_helper(parsed_input_args.observability)

    chains = parsed_input_args.chains
    chain = chains[0]
    challengers = parsed_input_args.challengers
    challenger = challengers[0]

    deployment_output = "/path/to/deployment_output"
    l1_config_env_vars = {
        "L1_RPC_URL": "L1_RPC_URL",
        "L1_RPC_KIND": "standard",
        "CL_RPC_URL": "CL_RPC_URL",
    }

    # We'll mock read_network_config_value since it returns a runtime value that we would not be able to retrieve
    dispute_game_factory_mock = "dispute_game_factory"
    kurtosistest.mock(util, "read_network_config_value").mock_return_value(
        dispute_game_factory_mock
    )
    challenger_private_key_mock = "challenger_private_key"
    kurtosistest.mock(util, "read_network_config_value").mock_return_value(
        challenger_private_key_mock
    )

    op_challenger_launcher.launch(
        plan=plan,
        params=parsed_input_args.challengers[0],
        l2s=[
            struct(
                network_id=1000,
                name="my-network",
                participants=[
                    struct(
                        cl_context=struct(
                            beacon_http_url="beacon_http_url",
                        ),
                        el_context=struct(
                            rpc_http_url="rpc_http_url",
                        ),
                    )
                ],
            )
        ],
        supervisors_params=[],
        l1_config_env_vars=l1_config_env_vars,
        deployment_output=deployment_output,
        observability_helper=observability_helper,
    )

    challenger_service_config = kurtosistest.get_service_config(
        service_name=challenger.service_name
    )
    expect.ne(challenger_service_config, None)
    expect.eq(challenger_service_config.image, challenger.image)
    expect.eq(challenger_service_config.env_vars, {})
    expect.eq(
        challenger_service_config.entrypoint,
        ["op-challenger"],
    )
    expect.eq(
        challenger_service_config.cmd,
        [
            "--cannon-l2-genesis=/network-configs/genesis-1000.json",
            "--cannon-rollup-config=/network-configs/rollup-1000.json",
            "--game-factory-address=challenger_private_key",
            "--datadir=/data/op-challenger/op-challenger-data",
            "--l1-beacon=CL_RPC_URL",
            "--l1-eth-rpc=L1_RPC_URL",
            "--l2-eth-rpc=rpc_http_url",
            "--private-key=challenger_private_key",
            "--rollup-rpc=beacon_http_url",
            "--cannon-prestates-url=https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon",
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port=9001",
        ],
    )
