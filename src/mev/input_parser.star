_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    # At the moment we only support rollup-boost
    "type": "rollup-boost",
    "builder_host": None,
    "builder_port": None,
}

_IMAGE_IDS = {
    "rollup-boost": _registry.ROLLUP_BOOST,
}


def parse(mev_args, network_params, participant_name, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # This string keep repeating in the error messages
    mev_log_string = "{} on network {}".format(participant_name, network_name)

    # Any extra attributes will cause an error
    _filter.assert_keys(
        mev_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in MEV configuration for " + mev_log_string + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    mev_params = _DEFAULT_ARGS | _filter.remove_none(mev_args or {})

    # Now we check that we either have none or both of builder_host & builder_port
    if mev_params["builder_host"] and not mev_params["builder_port"]:
        fail("Missing builder_port in MEV configuration for {}".format(mev_log_string))
    elif not mev_params["builder_host"] and mev_params["builder_port"]:
        fail("Missing builder_host in MEV configuration for {}".format(mev_log_string))

    # And default the image to the one in the registry
    mev_params["image"] = mev_params["image"] or _default_image(
        mev_params["type"], registry
    )

    # Add the service name
    mev_params["service_name"] = "op-mev-{}-{}-{}-{}".format(
        mev_params["type"], network_id, network_name, participant_name
    )

    # Add a bunch of labels
    mev_params["labels"] = {
        "op.kind": "mev",
        "op.network.id": str(network_id),
        "op.mev.type": mev_params["type"],
        "op.network.participant.name": participant_name,
    }

    # Add ports
    mev_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(number=8541),
    }

    return struct(**mev_params)


def _default_image(mev_type, registry):
    if mev_type in _IMAGE_IDS:
        return registry.get(_IMAGE_IDS[mev_type])
    else:
        fail("Invalid MEV type: {}".format(mev_type))
