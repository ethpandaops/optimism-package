_expansion = import_module("/src/util/expansion.star")
_filter = import_module("/src/util/filter.star")

_DEFAULT_ARGS = {
    "enabled": True,
    "participants": "*",
}


def parse(args, chains):
    return _filter.remove_none(
        [
            _parse_instance(superchain_args or {}, superchain_name, chains)
            for superchain_name, superchain_args in (args or {}).items()
        ]
    )


def _parse_instance(superchain_args, superchain_name, chains):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        superchain_args,
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in superchain configuration for "
        + superchain_name
        + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    # and merge the config with the defaults
    superchain_params = _DEFAULT_ARGS | _filter.remove_none(superchain_args)

    # We return early if the set is disabled
    if not superchain_params["enabled"]:
        return None

    # We expand the list of participants since we support a special "*" value to include all networks
    network_ids = [c["network_params"]["network_id"] for c in chains]
    superchain_params["participants"] = _expansion.expand_asterisc(
        superchain_params["participants"],
        network_ids,
        missing_value_message="network ID {0} does not exist, please check configuration for superchain "
        + superchain_name,
    )

    # No participants means that the superchain is disabled
    if len(superchain_params["participants"]) == 0:
        return None

    # We add the name to the config
    superchain_params["name"] = superchain_name

    return struct(**superchain_params)
