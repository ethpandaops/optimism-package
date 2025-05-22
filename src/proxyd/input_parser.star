_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    "extra_params": [],
}


def parse(proxyd_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        proxyd_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in proxyd configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    proxyd_params = _DEFAULT_ARGS | _filter.remove_none(proxyd_args or {})

    # And default the image to the one in the registry
    proxyd_params["image"] = proxyd_params["image"] or registry.get(_registry.PROXYD)

    # Add the service name
    proxyd_params["service_name"] = "proxyd-{}-{}".format(network_id, network_name)

    # Add ports
    proxyd_params["ports"] = {
        _net.HTTP_PORT_NAME: _net.port(number=8080),
    }

    # Add labels
    proxyd_params["labels"] = {
        "op.kind": "proxyd",
        "op.network.id": network_id,
    }

    return struct(**proxyd_params)
