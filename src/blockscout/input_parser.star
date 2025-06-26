_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    "verifier_image": None,
}


def parse(blockscout_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        blockscout_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in blockscout configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    blockscout_params = _DEFAULT_ARGS | _filter.remove_none(blockscout_args or {})

    if not blockscout_params["enabled"]:
        return None

    return struct(
        database=struct(
            service_name="op-blockscout-db-{}-{}".format(network_id, network_name),
        ),
        blockscout=struct(
            image=blockscout_params["image"] or registry.get(_registry.OP_BLOCKSCOUT),
            service_name="op-blockscout-{}-{}".format(network_id, network_name),
            labels={
                "op.kind": "blockscout",
                "op.network.id": str(network_id),
            },
            ports={
                _net.HTTP_PORT_NAME: _net.port(number=4000),
            },
        ),
        verifier=struct(
            image=blockscout_params["verifier_image"]
            or registry.get(_registry.OP_BLOCKSCOUT_VERIFIER),
            service_name="op-blockscout-verifier-{}-{}".format(
                network_id, network_name
            ),
            labels={
                "op.kind": "blockscout-verifier",
                "op.network.id": str(network_id),
            },
            ports={
                _net.HTTP_PORT_NAME: _net.port(number=8050),
            },
        ),
    )
