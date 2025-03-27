constants = import_module("../package_io/constants.star")

# The min/max CPU/memory that tx-fuzzer can use
MIN_CPU = 100
MAX_CPU = 1000
MIN_MEMORY = 20
MAX_MEMORY = 300


def launch(
    plan,
    service_name,
    el_uri,
    tx_fuzzer_params,
    global_node_selectors,
):
    config = get_config(
        el_uri,
        tx_fuzzer_params,
        global_node_selectors,
    )
    plan.add_service(service_name, config)


def get_config(
    el_uri,
    tx_fuzzer_params,
    node_selectors,
):
    cmd = [
        "spam",
        "--rpc={}".format(el_uri),
        "--sk={0}".format(constants.dev_accounts[0]["private_key"]),
    ]

    if len(tx_fuzzer_params.tx_fuzzer_extra_args) > 0:
        cmd.extend([param for param in tx_fuzzer_params.tx_fuzzer_extra_args])

    return ServiceConfig(
        image=tx_fuzzer_params.image,
        cmd=cmd,
        min_cpu=MIN_CPU,
        max_cpu=MAX_CPU,
        min_memory=MIN_MEMORY,
        max_memory=MAX_MEMORY,
        node_selectors=node_selectors,
    )
