_el_input_parser = import_module("/src/el/input_parser.star")
_cl_input_parser = import_module("/src/cl/input_parser.star")

_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    # At the moment we only support rollup-boost
    "type": "rollup-boost",
    "external_el_builder": None,
    "el_builder": None,
    "cl_builder": None,
}

_DEFAULT_EXTERNAL_EL_BUILDER_ARGS = {
    "host": None,
    "port": None,
}

_IMAGE_IDS = {
    "rollup-boost": _registry.ROLLUP_BOOST,
}


def parse(mev_args, network_params, participant_name, participant_index, registry):
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

    if not mev_params["enabled"]:
        return None

    # Now we parse the builder configuration
    mev_params["external_el_builder"] = _parse_external_el_builder(
        external_el_builder_args=mev_params["external_el_builder"],
        log_string=mev_log_string,
    )
    if mev_params["external_el_builder"]:
        # We will fail if both the external builder and the el/cl builders were specified
        if mev_params["el_builder"]:
            fail(
                "Invalid combination of el_builder and external_el_builder in MEV configuration for {}".format(
                    mev_log_string
                )
            )

        if mev_params["cl_builder"]:
            fail(
                "Invalid combination of cl_builder and external_el_builder in MEV configuration for {}".format(
                    mev_log_string
                )
            )
    else:
        mev_params["el_builder"] = _el_input_parser.parse_builder(
            el_args=mev_params["el_builder"],
            participant_name=participant_name,
            participant_index=participant_index,
            network_params=network_params,
            registry=registry,
        )

        mev_params["cl_builder"] = _cl_input_parser.parse_builder(
            cl_args=mev_params["cl_builder"],
            participant_name=participant_name,
            participant_index=participant_index,
            network_params=network_params,
            registry=registry,
        )

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
        "op.network.participant.index": str(participant_index),
        "op.network.participant.name": participant_name,
    }

    # Add ports
    mev_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(number=8541),
    }

    return struct(**mev_params)


def _parse_external_el_builder(external_el_builder_args, log_string):
    if not external_el_builder_args:
        return None

    # Any extra attributes will cause an error
    _filter.assert_keys(
        mev_args or {},
        _DEFAULT_EXTERNAL_EL_BUILDER_ARGS.keys(),
        "Invalid attributes in MEV external EL builder configuration for "
        + log_string
        + ": {}",
    )

    # No host and no port means the external builder is disabled
    if not external_el_builder_args["host"] and not external_el_builder_args["port"]:
        return None

    # We check that we either have none or both of builder_host & builder_port
    if external_el_builder_args["host"] and not external_el_builder_args["port"]:
        fail(
            "Missing port attribute in MEV external EL builder configuration for {}".format(
                log_string
            )
        )
    elif not external_el_builder_args["host"] and external_el_builder_args["port"]:
        fail(
            "Missing host attribute in MEV external EL builder configuration for {}".format(
                log_string
            )
        )

    return struct(**external_el_builder_args)


def _default_image(mev_type, registry):
    if mev_type in _IMAGE_IDS:
        return registry.get(_IMAGE_IDS[mev_type])
    else:
        fail("Invalid MEV type: {}".format(mev_type))
