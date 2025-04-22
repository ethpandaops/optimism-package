op_challenger_launcher = import_module(
    "/src/challenger/op-challenger/op_challenger_launcher.star"
)
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
op_supervisor_launcher = import_module(
    "/src/interop/op-supervisor/op_supervisor_launcher.star"
)
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
util = import_module("/src/util.star")


def test_launch_with_defaults(plan):
    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
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
        ip_addr="1.2.3.4",
    )
    cl_context = struct(
        beacon_http_url="beacon_http_url",
        ip_addr="4.3.2.1",
    )
    # el_context, cl_context = launch_test_el_cl(plan, parsed_input_args)

    observability_helper = observability.make_helper(parsed_input_args.observability)

    chains = parsed_input_args.chains
    chain = chains[0]
    l2_num = 0
    challenger_service_name = "op-challenger"
    challenger_image = input_parser.DEFAULT_CHALLENGER_IMAGES["op-challenger"]

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

    supervisor = op_supervisor_launcher.launch(
        plan=plan,
        interop_set=struct(
            enabled=True,
            name="interop-set",
            participants=["1000"],
            supervisor_params=struct(
                enabled=True,
                image="op-supervisor:latest",
                dependency_set=None,
                extra_params=[],
            ),
        ),
        l1_config_env_vars=l1_config_env_vars,
        l2s=[
            struct(
                network_id="1000",
                participants=[
                    struct(
                        el_context=el_context,
                        cl_context=cl_context,
                    )
                ],
            )
        ],
        jwt_file="/path/to/jwt_file",
        observability_helper=observability_helper,
    )

    op_challenger_launcher.launch(
        plan=plan,
        l2_num=l2_num,
        service_name=challenger_service_name,
        image=challenger_image,
        el_context=el_context,
        cl_context=cl_context,
        l1_config_env_vars=l1_config_env_vars,
        deployment_output=deployment_output,
        network_params=chain.network_params,
        challenger_params=chain.challenger_params,
        supervisor=supervisor,
        observability_helper=observability_helper,
    )

    challenger_service_config = kurtosistest.get_service_config(
        service_name=challenger_service_name
    )
    expect.ne(challenger_service_config, None)
    expect.eq(challenger_service_config.image, challenger_image)
    expect.eq(challenger_service_config.env_vars, {})
    expect.eq(
        challenger_service_config.entrypoint,
        ["sh", "-c"],
    )
    expect.eq(
        challenger_service_config.cmd,
        [
            "mkdir -p /data/op-challenger/op-challenger-data && op-challenger --cannon-l2-genesis=/network-configs/genesis-2151908.json --cannon-rollup-config=/network-configs/rollup-2151908.json --game-factory-address=challenger_private_key --datadir=/data/op-challenger/op-challenger-data --l1-beacon=CL_RPC_URL --l1-eth-rpc=L1_RPC_URL --l2-eth-rpc=rpc_http_url --private-key=challenger_private_key --rollup-rpc=beacon_http_url --trace-type=cannon,permissioned --metrics.enabled --metrics.addr=0.0.0.0 --metrics.port=9001 --supervisor-rpc=http://op-supervisor-interop-set:8545 --cannon-depset-config=dummy-file.json --cannon-prestates-url=https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon"
        ],
    )
