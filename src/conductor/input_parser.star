_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    "extra_params": [],
    "admin": True,
    "proxy": True,
    "paused": False,
    "bootstrap": False,
    "pprof_enabled": False,
    # Optional overrides
    "websocket_port": None,
    "healthcheck_interval": None,
    "healthcheck_min_peer_count": None,
    "healthcheck_unsafe_interval": None,
}


def parse(
    conductor_args, network_params, participant_name, participant_index, registry
):
    network_id = network_params.network_id
    network_name = network_params.name

    # This string keep repeating in the error messages
    conductor_log_string = "{} on network {}".format(participant_name, network_name)

    # Any extra attributes will cause an error
    _filter.assert_keys(
        conductor_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in conductor configuration for "
        + conductor_log_string
        + ": {}",
    )

    # Merge with defaults first
    conductor_params = _DEFAULT_ARGS | _filter.remove_none(conductor_args or {})

    if not conductor_params["enabled"]:
        return None

    # And default the image to the one in the registry
    conductor_params["image"] = conductor_params.get("image") or registry.get(
        _registry.OP_CONDUCTOR
    )

    # Add the service name
    conductor_params["service_name"] = "op-conductor-{}-{}-{}".format(
        network_id, network_name, participant_name
    )

    # Add ports
    conductor_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(number=8547),
        _net.CONSENSUS_PORT_NAME: _net.port(number=50050),
    }

    # Add labels
    conductor_params["labels"] = {
        "op.kind": "conductor",
        "op.network.id": str(network_id),
        "op.network.participant.index": str(participant_index),
        "op.network.participant.name": participant_name,
        "op.conductor.type": "op-conductor",
    }

    # Drop None-valued optional fields to keep output minimal AFTER all defaults are applied
    conductor_params = _filter.remove_none(conductor_params)

    return struct(**conductor_params)
