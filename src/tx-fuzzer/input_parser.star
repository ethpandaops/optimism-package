_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    "extra_params": [],
    "min_cpu": 100,
    "max_cpu": 1000,
    "min_memory": 20,
    "max_memory": 300,
}


def parse(tx_fuzzer_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        tx_fuzzer_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in tx fuzzer configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    tx_fuzzer_params = _DEFAULT_ARGS | _filter.remove_none(tx_fuzzer_args or {})

    if not tx_fuzzer_params["enabled"]:
        return None

    # And default the image to the one in the registry
    tx_fuzzer_params["image"] = tx_fuzzer_params["image"] or registry.get(
        _registry.TX_FUZZER
    )

    # Add the service name
    tx_fuzzer_params["service_name"] = "op-tx-fuzzer-{}-{}".format(
        network_id, network_name
    )

    # Add labels
    tx_fuzzer_params["labels"] = {
        "op.kind": "tx-fuzzer",
        "op.network.id": network_id,
    }

    return struct(**tx_fuzzer_params)
