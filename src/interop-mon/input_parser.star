"""Input parser for the op-interop-mon service."""

_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
}

def parse(args, network_params, registry):
    """Parse the input arguments for the op-interop-mon service.

    Args:
        args: The input arguments for the op-interop-mon service.
        network_params: The network parameters.
        registry: The registry containing the docker images.
    Returns:
        A struct containing the parsed arguments or None if disabled.
    """
    # Any extra attributes will cause an error
    _filter.assert_keys(
        args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in interop-mon configuration: {}",
    )

    # We filter the None values so that we can merge dicts easily
    interop_params = _DEFAULT_ARGS | _filter.remove_none(args or {})

    if not interop_params["enabled"]:
        return None

    # Default the image to the one in the registry if not specified
    interop_params["image"] = interop_params["image"] or registry.get(_registry.OP_INTEROP_MON)

    return struct(**interop_params)
