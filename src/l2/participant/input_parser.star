_registry = import_module("/src/package_io/registry.star")
_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")

_el_input_parser = import_module("./el/input_parser.star")
_cl_input_parser = import_module("./cl/input_parser.star")

_DEFAULT_PARTICIPANT_ARGS = {
    "el": None,
    "el_builder": None,
    "cl": None,
    "cl_builder": None,
}


def parse(args, network_id, registry):
    return _filter.remove_none(
        [
            _parse_instance(
                participant_args or {}, participant_name, network_id, registry
            )
            for participant_name, participant_args in (args or {}).items()
        ]
    )


def _parse_instance(participant_args, participant_name, network_id, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        participant_args,
        _DEFAULT_PARTICIPANT_ARGS.keys(),
        "Invalid attributes in participant configuration for "
        + participant_name
        + " on network "
        + str(network_id)
        + ": {}",
    )

    # We make sure the name adheres to our standards
    _id.assert_id(participant_name)

    el_args = participant_args.get("el", {})
    cl_args = participant_args.get("cl", {})

    return struct(
        el=_el_input_parser.parse(el_args, participant_name, network_id, registry),
        el_builder=_el_input_parser.parse_builder(
            el_args, participant_name, network_id, registry
        ),
        cl=_cl_input_parser.parse(cl_args, participant_name, network_id, registry),
        cl_builder=_cl_input_parser.parse_builder(
            cl_args, participant_name, network_id, registry
        ),
    )
