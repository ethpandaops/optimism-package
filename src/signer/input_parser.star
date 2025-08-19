_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
}


def parse(signer_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        signer_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in signer configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    signer_params = _DEFAULT_ARGS | _filter.remove_none(signer_args or {})

    if not signer_params["enabled"]:
        return None

    # And default the image to the one in the registry
    signer_params["image"] = signer_params["image"] or registry.get(_registry.OP_SIGNER)

    # Add the service name
    signer_params["service_name"] = "signer-{}-{}".format(network_id, network_name)

    # Add labels
    signer_params["labels"] = {
        "op.kind": "signer",
        "op.network.id": str(network_id),
    }

    return struct(**signer_params)
