_filter = import_module("/src/util/filter.star")
_registry = import_module("/src/package_io/registry.star")
_el_input_parser = import_module("/src/el/input_parser.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    "type": "flashblocks-rpc",
    "extra_params": [],
    "extra_env_vars": {},
    "extra_labels": {},
    "log_level": None,
    "max_cpu": 0,
    "max_mem": 0,
    "min_cpu": 0,
    "min_mem": 0,
    "node_selectors": {},
    "pprof_enabled": False,
    "tolerations": [],
    "volume_size": 0,
}


def parse(rpc_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    _filter.assert_keys(
        rpc_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in flashblocks RPC configuration for network {}".format(
            network_name
        ),
    )

    rpc_params = _DEFAULT_ARGS | _filter.remove_none(rpc_args or {})

    if not rpc_params["enabled"]:
        return None

    if not rpc_params.get("image"):
        rpc_params["image"] = registry.get(_registry.FLASHBLOCKS_RPC)

    # Filter out fields that aren't valid for EL input parser
    el_compatible_params = {}
    for key, value in rpc_params.items():
        if key not in ["enabled", "pprof_enabled"]:
            el_compatible_params[key] = value

    # TODO(#979): We should check whether any participant has the same name
    rpc_params = _el_input_parser.parse(
        el_args=el_compatible_params,
        participant_name="flashblocks-rpc-do-not-use",
        participant_index=0,
        network_params=network_params,
        registry=registry,
    )

    return rpc_params
