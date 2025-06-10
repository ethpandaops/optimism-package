_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    "cmd": None,
}

# FIXME We should not hardcode da-server here, but it's not a priority at this point
#
# DA is basically anything at this point since both the image and command can be specified using the params.
# This should work similarly to e.g. EL or CL clients with image and type attributes
_DA_TYPE = "da-server"


def parse(da_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        da_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in DA configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    da_params = _DEFAULT_ARGS | _filter.remove_none(da_args or {})

    if not da_params["enabled"]:
        return None

    # And default the image to the one in the registry
    da_params["image"] = da_params["image"] or registry.get(_registry.DA_SERVER)

    # Add the service name
    da_params["service_name"] = "op-da-{}-{}-{}".format(
        _DA_TYPE, network_id, network_name
    )

    # Add a bunch of labels
    da_params["labels"] = {
        "op.kind": "da",
        "op.network.id": str(network_id),
        "op.da.type": _DA_TYPE,
    }

    # Add ports
    da_params["ports"] = {
        _net.HTTP_PORT_NAME: _net.port(number=3100),
    }

    # FIXME We should not hardcode the command here, but it's not a priority at this point
    da_params["cmd"] = da_params["cmd"] or [
        "da-server",  # uses keccak commitments by default
        # We use the file storage backend instead of s3 for simplicity.
        # Blobs and commitments are stored in the /home directory (which already exists).
        # Note that this storage is ephemeral because we aren't mounting an external kurtosis file.
        # This means that the data is lost when the container is deleted.
        "--file.path=/home",
        "--addr=0.0.0.0",
        "--port={}".format(da_params["ports"][_net.HTTP_PORT_NAME].number),
        "--log.level=debug",
    ]

    return struct(**da_params)
