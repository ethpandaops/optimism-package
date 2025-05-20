_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    "extra_params": [],
}


def parse(batcher_args, l2_name, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        batcher_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in batcher configuration for " + l2_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    batcher_params = _DEFAULT_ARGS | _filter.remove_none(batcher_args or {})

    # And default the image to the one in the registry
    batcher_params["image"] = batcher_params["image"] or registry.get(
        _registry.OP_BATCHER
    )

    # Add the service name
    batcher_params["service_name"] = "op-batcher-{}".format(l2_name)

    # Add ports
    batcher_params["ports"] = {
        _net.HTTP_PORT_NAME: _net.port(number=8548),
    }

    return struct(**batcher_params)
