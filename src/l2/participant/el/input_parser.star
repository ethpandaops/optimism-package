_registry = import_module("/src/package_io/registry.star")
_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")

_DEFAULT_ARGS = {
    "type": "op-geth",
    "image": None,
    "log_level": None,
    "extra_env_vars": {},
    "extra_labels": {},
    "extra_params": [],
    "tolerations": [],
    "volume_size": 0,
    "min_cpu": 0,
    "max_cpu": 0,
    "min_mem": 0,
    "max_mem": 0,
}


def parse(args, participant_name, network_id, registry):
    return _parse(args, participant_name, network_id, registry, "el")


def parse_builder(args, participant_name, network_id, registry):
    return _parse(args, participant_name, network_id, registry, "el_builder")


def _parse(args, participant_name, network_id, registry, el_kind):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        args,
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in EL configuration for "
        + participant_name
        + " on network "
        + str(network_id)
        + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    # and merge the config with the defaults
    el_params = _DEFAULT_ARGS | _filter.remove_none(args)

    # We default the image to the one in the registry
    #
    # This step, as a side effect, also verifies the EL type
    el_params["image"] = el_params["image"] or _default_image(
        el_params["type"], registry
    )

    el_params["name"] = participant_name
    el_params["service_name"] = "op-el-{}-{}-{}".format(
        network_id, participant_name, el_params["type"]
    )

    # Draft of what the labels could look like
    el_params["labels"] = {
        "op.kind": el_kind,
        "ep.network.id": network_id,
        "op.el.type": el_params["type"],
    }

    # We register the RPC port on the EL
    el_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(number=8545),
    }

    return struct(**el_params)


def _default_image(participant_type, registry):
    if participant_type == "op-geth":
        return registry.get(_registry.OP_GETH)
    elif participant_type == "op-reth":
        return registry.get(_registry.OP_RETH)
    elif participant_type == "op-erigon":
        return registry.get(_registry.OP_ERIGON)
    elif participant_type == "op-nethermind":
        return registry.get(_registry.OP_NETHERMIND)
    elif participant_type == "op-besu":
        return registry.get(_registry.OP_BESU)
    elif participant_type == "op-rbuilder":
        return registry.get(_registry.OP_RBUILDER)
    else:
        fail("Invalid EL type: {}".format(participant_type))
