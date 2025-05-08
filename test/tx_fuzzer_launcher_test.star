transaction_fuzzer = import_module("/src/transaction_fuzzer/transaction_fuzzer.star")
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
constants = import_module("/src/package_io/constants.star")
util = import_module("/src/util.star")

_registry = import_module("/src/package_io/registry.star")


def test_launch_with_defaults(plan):
    tx_fuzzer_image = "tx-fuzz:latest"

    reg = _registry.Registry(
        {
            _registry.TX_FUZZER: tx_fuzzer_image,
        }
    )
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
        registry=reg,
    )

    chains = parsed_input_args.chains
    chain = chains[0]
    service_name = "op-transaction-fuzzer"

    el_rpc_url = "http://rpc.el"
    transaction_fuzzer.launch(
        plan=plan,
        service_name=service_name,
        el_uri=el_rpc_url,
        tx_fuzzer_params=chain.tx_fuzzer_params,
        global_node_selectors=parsed_input_args.global_node_selectors,
    )

    fuzzer_service_config = kurtosistest.get_service_config(service_name=service_name)
    expect.ne(fuzzer_service_config, None)
    expect.eq(fuzzer_service_config.image, tx_fuzzer_image)
    expect.eq(fuzzer_service_config.env_vars, {})
    expect.eq(
        fuzzer_service_config.entrypoint,
        [],
    )
    expect.eq(
        fuzzer_service_config.cmd,
        [
            "spam",
            "--rpc={}".format(el_rpc_url),
            "--sk={0}".format(constants.dev_accounts[0]["private_key"]),
        ],
    )
