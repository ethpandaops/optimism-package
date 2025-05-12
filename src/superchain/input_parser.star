_expansion = import_module("/src/util/expansion.star")
_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")

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

    _id.assert_id(superchain_name)

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

    # We add interop RPC port to the superchain config
    #
    # This is used for communication between supervisors and CL clients
    # and since it's not a port exposed on on the supervisor but rather on the CL client,
    # we put it here (at least temporarily)
    #
    # TODO Once the input parsers for CL clients are refactored, this will be moved there
    superchain_params["ports"] = {
        _net.INTEROP_RPC_PORT_NAME: _net.port(number=9645, application_protocol="ws"),
    }

    # We'll create a dependency set for the superchain based on all the participants
    superchain_params["dependency_set"] = struct(
        name="superchain-depset-{}".format(superchain_name),
        path="superchain-depset-{}.json".format(superchain_name),
        value=_create_dependency_set(superchain_params["participants"]),
    )

    return struct(**superchain_params)


def _create_dependency_set(network_ids):
    return {
        "dependencies": {
            str(network_id): {
                "chainIndex": str(network_id),
                "activationTime": 0,
                "historyMinTime": 0,
            }
            for network_id in network_ids
        }
    }
