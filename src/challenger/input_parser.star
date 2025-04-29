_util = import_module("/src/util.star")
_expansion = import_module("/src/util/expansion.star")

_DEFAULT_ARGS = {
    "enabled": True,
    "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-challenger:develop",
    "extra_params": [],
    "participants": "*",
    "cannon_prestate_path": "",
    "cannon_prestates_url": "https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon",
    "cannon_trace_types": ["cannon", "permissioned"],
}


def parse(args, chains):
    return [
        _parse_instance(challenger_args or {}, challenger_name, chains)
        for challenger_name, challenger_args in (args or {}).items()
    ]


def _parse_instance(challenger_args, challenger_name, chains):
    # We first filter the None values so that we can merge dicts easily
    challenger_params = _DEFAULT_ARGS | _util.filter_none(
        challenger_args
    )

    # We expand the list of participants since we support a special "*" value to include all networks
    network_ids = [c["network_params"]["network_id"] for c in chains]
    challenger_params["participants"] = _expansion.expand_asterisc(
        challenger_params["participants"],
        network_ids,
        missing_value_message="network ID {0} does not exist, please check challenger configuration for challenger "
        + challenger_name,
    )

    # We add name & service name
    challenger_params["name"] = challenger_name
    challenger_params["service_name"] = "op-challenger-{}".format(challenger_name)

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

    return challenger_params
