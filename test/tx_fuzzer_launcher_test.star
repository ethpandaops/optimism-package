tx_fuzzer_launcher = import_module(
    "/src/transaction_fuzzer/transaction_fuzzer.star"
)
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
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
                    "additional_services": [
                        "tx_fuzzer",
                    ],
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
    el_context, cl_context = launch_test_el_cl(plan, parsed_input_args)

    fuzzer_service_name = "tx-fuzzer"
    fuzzer_image = input_parser.DEFAULT_TX_FUZZER_IMAGES["tx-fuzzer"]

    transaction_fuzzer.launch(
        plan=plan,
        el_uri=EL_RPC_URL,
        tx_fuzzer_params=[],
        global_node_selectors=[],
    )

    fuzzer_service_config = kurtosistest.get_service_config(
        service_name=fuzzer_service_name
    )
    expect.ne(fuzzer_service_config, None)
    expect.eq(fuzzer_service_config.image, fuzzer_image)
    expect.eq(fuzzer_service_config.env_vars, {})
    expect.eq(
        fuzzer_service_config.entrypoint,
        ["sh", "-c"],
    )
    expect.eq(
        fuzzer_service_config.cmd,
        [
            "/tx-fuzz.bin spam --rpc=EL_RPC_URL --sk={}".format(
                constants.dev_accounts[0]["private_key"]
            )
        ],
    )
