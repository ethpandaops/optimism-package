_expansion = import_module("/src/util/expansion.star")
_filter = import_module("/src/util/filter.star")
_id = import_module("/src/util/id.star")

_DEFAULT_ARGS = {
    "enabled": True,
    "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-challenger:develop",
    "extra_params": [],
    "participants": "*",
    "cannon_prestate_path": "",
    "cannon_prestates_url": "https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon",
    "cannon_trace_types": [],
    "datadir": "/data/op-challenger/op-challenger-data",
}


def parse(args, chains):
    return _filter.remove_none(
        [
            _parse_instance(challenger_args or {}, challenger_name, chains)
            for challenger_name, challenger_args in (args or {}).items()
        ]
    )


def _parse_instance(challenger_args, challenger_name, chains):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        challenger_args,
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in challenger configuration for "
        + challenger_name
        + ": {}",
    )

    _id.assert_id(challenger_name)

    # We filter the None values so that we can merge dicts easily
    # and merge the config with the defaults
    challenger_params = _DEFAULT_ARGS | _filter.remove_none(challenger_args)

    if not challenger_params["enabled"]:
        return None

    # We expand the list of participants since we support a special "*" value to include all networks
    network_ids = [c["network_params"]["network_id"] for c in chains]
    challenger_params["participants"] = _expansion.expand_asterisc(
        challenger_params["participants"],
        network_ids,
        missing_value_message="network ID {0} does not exist, please check challenger configuration for challenger "
        + challenger_name,
    )

    # No participants means that the challenger is disabled
    if len(challenger_params["participants"]) == 0:
        return None

    # We add name & service name
    challenger_params["name"] = challenger_name
    challenger_params["service_name"] = "op-challenger-{}-{}".format(
        challenger_name,
        "-".join([str(p) for p in challenger_params["participants"]]),
    )

    # Now we make sure to cover the prestate arg combinations
    #
    # First we check we only have one of them defined
    if (
        challenger_params["cannon_prestate_path"]
        and challenger_params["cannon_prestates_url"]
    ):
        fail(
            "Only one of cannon_prestate_path and cannon_prestates_url can be set for challenger {}".format(
                challenger_name
            )
        )

    # And we also need to make sure we have at least one of them defined
    if (
        not challenger_params["cannon_prestate_path"]
        and not challenger_params["cannon_prestates_url"]
    ):
        fail(
            "At least one of cannon_prestate_path and cannon_prestates_url must be set for challenger {}".format(
                challenger_name
            )
        )

    return struct(**challenger_params)
