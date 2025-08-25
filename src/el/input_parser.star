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
    "node_selectors": {},
    "tolerations": [],
    "volume_size": 0,
    "min_cpu": 0,
    "max_cpu": 0,
    "min_mem": 0,
    "max_mem": 0,
}

_DEFAULT_FLASHBLOCKS_WS_PORT = 1111

_DEFAULT_BUILDER_ARGS = _DEFAULT_ARGS | {
    "key": None,
    # Flashblocks-related defaults for builders
    "flashblocks_ms_per_slot": 250,
}

# EL clients have a type property that maps to an image
_IMAGE_IDS = {
    "op-geth": _registry.OP_GETH,
    "op-reth": _registry.OP_RETH,
    "op-erigon": _registry.OP_ERIGON,
    "op-nethermind": _registry.OP_NETHERMIND,
    "op-besu": _registry.OP_BESU,
    "op-rbuilder": _registry.OP_RBUILDER,
}


def parse(el_args, participant_name, participant_index, network_params, registry):
    return _parse(
        el_args=el_args,
        default_args=_DEFAULT_ARGS,
        participant_name=participant_name,
        participant_index=participant_index,
        network_params=network_params,
        registry=registry,
        el_kind="el",
    )


def parse_builder(
    el_args, participant_name, participant_index, network_params, registry
):
    el_params = _parse(
        el_args=el_args,
        default_args=_DEFAULT_BUILDER_ARGS,
        participant_name=participant_name,
        participant_index=participant_index,
        network_params=network_params,
        registry=registry,
        el_kind="elbuilder",
    )
    el_params.ports[_net.FLASHBLOCKS_WS_PORT_NAME] = _net.port(
        number=_DEFAULT_FLASHBLOCKS_WS_PORT, application_protocol="ws"
    )
    return el_params


def _parse(
    el_args,
    default_args,
    participant_name,
    participant_index,
    network_params,
    registry,
    el_kind,
):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        el_args or {},
        default_args.keys(),
        "Invalid attributes in EL configuration for "
        + participant_name
        + " on network "
        + network_name
        + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    # and merge the config with the defaults
    el_params = default_args | _filter.remove_none(el_args or {})

    # We default the image to the one in the registry
    #
    # This step, as a side effect, also verifies the EL type
    el_params["image"] = el_params["image"] or _default_image(
        el_params["type"], registry
    )

    el_params["name"] = participant_name
    el_params["service_name"] = "op-{}-{}-{}-{}".format(
        el_kind, network_id, participant_name, el_params["type"]
    )

    # Draft of what the labels could look like
    el_params["labels"] = {
        "op.kind": el_kind,
        "op.network.id": str(network_id),
        "op.network.participant.index": str(participant_index),
        "op.network.participant.name": participant_name,
        "op.el.type": el_params["type"],
    }

    # We register the RPC port on the EL
    el_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(number=8545),
        _net.WS_PORT_NAME: _net.port(number=8546, application_protocol="ws"),
        _net.TCP_DISCOVERY_PORT_NAME: _net.port(number=30303),
        _net.UDP_DISCOVERY_PORT_NAME: _net.port(number=30303, transport_protocol="UDP"),
        _net.ENGINE_RPC_PORT_NAME: _net.port(number=8551),
    }

    return struct(**el_params)


def _default_image(participant_type, registry):
    if participant_type in _IMAGE_IDS:
        return registry.get(_IMAGE_IDS[participant_type])
    else:
        fail("Invalid EL type: {}".format(participant_type))
