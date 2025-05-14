_filter = import_module("/src/util/filter.star")

_l2_participant_input_parser = import_module("./participant/input_parser.star")

_DEFAULT_ARGS = {
    "participants": {},
    "network_id": None,
}


def parse(args, registry):
    return _filter.remove_none(
        [
            _parse_instance(l2_args or {}, l2_id, registry)
            for l2_id, l2_args in (args or {}).items()
        ]
    )


def _parse_instance(l2_args, l2_id, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        l2_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in L2 configuration for " + l2_id + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    l2_params = _DEFAULT_ARGS | _filter.remove_none(l2_args or {})

    # We'll make sure that the network ID is a number
    l2_params["network_id"] = _assert_l2_id(l2_id)

    l2_params["participants"] = _l2_participant_input_parser.parse(
        l2_params["participants"], l2_params["network_id"], registry
    )

    return struct(
        **l2_params,
    )


def _assert_l2_id(l2_id):
    if type(l2_id) == "int":
        return l2_id

    if type(l2_id) == "string":
        if l2_id.isdigit():
            return int(l2_id)

    fail("L2 ID must be a positive integer in decimal base, got {}".format(l2_id))
