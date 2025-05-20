_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    "extra_params": [],
}


def parse(proxyd_args, l2_name, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        proxyd_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in proxyd configuration for " + l2_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    proxyd_params = _DEFAULT_ARGS | _filter.remove_none(proxyd_args or {})

    # And default the image to the one in the registry
    proxyd_params["image"] = proxyd_params["image"] or registry.get(_registry.PROXYD)

    # Add the service name
    proxyd_params["service_name"] = "proxyd-{}".format(l2_name)

    # Add ports
    proxyd_params["ports"] = {
        _net.HTTP_PORT_NAME: _net.port(number=8080),
    }

    return struct(**proxyd_params)
