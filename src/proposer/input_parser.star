_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    "extra_params": [],
    "game_type": 1,
    "proposal_interval": "10m",
    "pprof_enabled": False,
}


def parse(proposer_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        proposer_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in proposer configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    proposer_params = _DEFAULT_ARGS | _filter.remove_none(proposer_args or {})

    # And default the image to the one in the registry
    proposer_params["image"] = proposer_params["image"] or registry.get(
        _registry.OP_PROPOSER
    )

    # Add the service name
    proposer_params["service_name"] = "op-proposer-{}-{}".format(
        network_id, network_name
    )

    # Add ports
    proposer_params["ports"] = {
        _net.HTTP_PORT_NAME: _net.port(number=8560),
    }

    # Add labels
    proposer_params["labels"] = {
        "op.kind": "proposer",
        "op.network.id": str(network_id),
    }

    return struct(**proposer_params)
