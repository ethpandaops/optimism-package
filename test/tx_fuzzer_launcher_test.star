tx_fuzzer = import_module("/src/tx-fuzzer/launcher.star")
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
constants = import_module("/src/package_io/constants.star")
util = import_module("/src/util.star")

_registry = import_module("/src/package_io/registry.star")


def test_tx_fuzzer_launch_with_defaults(plan):
    tx_fuzzer_image = "tx-fuzz:latest"

    reg = _registry.Registry(
        {
            _registry.TX_FUZZER: tx_fuzzer_image,
        }
    )
    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": {
                "opkurtosis": {
                    "participants": {
                        "node0": {
                            "el": {
                                "type": "op-reth",
                                "image": "op-reth:latest",
                            },
                            "cl": {
                                "type": "op-node",
                                "image": "op-node:latest",
                            },
                        }
                    },
                    "tx_fuzzer_params": {
                        "enabled": True,
                    },
                }
            }
        },
        registry=reg,
    )

    chains = parsed_input_args.chains
    chain = chains[0]

    el_rpc_url = "http://rpc.el"
    tx_fuzzer.launch(
        plan=plan,
        params=chain.tx_fuzzer_params,
        el_context=struct(
            rpc_port_num=8888,
            ip_addr="127.0.0.1",
            service_name="rpc-el",
        ),
        node_selectors=parsed_input_args.global_node_selectors,
    )

    fuzzer_service_config = kurtosistest.get_service_config(
        service_name=chain.tx_fuzzer_params.service_name
    )
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
            "--rpc={}".format("http://rpc-el:8888"),
            "--sk={0}".format(constants.dev_accounts[0]["private_key"]),
        ],
    )
