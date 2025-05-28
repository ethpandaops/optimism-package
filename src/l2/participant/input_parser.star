_registry = import_module("/src/package_io/registry.star")
_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")

_el_input_parser = import_module("./el/input_parser.star")
_cl_input_parser = import_module("./cl/input_parser.star")

_DEFAULT_ARGS = {
    "el": None,
    "el_builder": None,
    "cl": None,
    "cl_builder": None,
    "sequencer": None,
}


def parse(args, network_params, registry):
    return _apply_sequencers(
        participants_params=_filter.remove_none(
            [
                _parse_instance(
                    participant_args or {}, participant_name, network_params, registry
                )
                for participant_name, participant_args in (args or {}).items()
            ]
        ),
        network_params=network_params,
    )


def _parse_instance(participant_args, participant_name, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    # Any extra attributes will cause an error
    _filter.assert_keys(
        participant_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in participant configuration for "
        + participant_name
        + " on network "
        + network_name
        + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    participant_params = _DEFAULT_ARGS | _filter.remove_none(participant_args or {})

    # We make sure the name adheres to our standards
    _id.assert_id(participant_name)

    # Now we make sure the sequencer property is valid
    #
    # This property can at this point hold several types of values:
    #
    # - boolean True means this node is a sequencer
    # - boolean False/None/falsy value means this node is not a sequencer
    # - string means that this node is not a sequencer and will be connected to a sequencer with this name
    #
    # In the last case, we need to make sure the node is not trying to connect to self
    sequencer = participant_params["sequencer"]
    if sequencer:
        type_of_sequencer = type(sequencer)

        # If we get a boolean True, we'll change it to the name of the node itself
        # so that it is consistent with the rest
        if sequencer == True:
            sequencer = participant_name
        # We'll fail on any invalid types
        elif (
            type_of_sequencer != "string"
            and type_of_sequencer != "bool"
            and type_of_sequencer != "NoneType"
        ):
            fail(
                "Invalid sequencer value for participant {} on network {}: expected string or bool, got {} {}".format(
                    participant_name, network_name, type_of_sequencer, sequencer
                )
            )

    return struct(
        el=_el_input_parser.parse(
            participant_params["el"], participant_name, network_id, registry
        ),
        el_builder=_el_input_parser.parse_builder(
            participant_params["el_builder"], participant_name, network_id, registry
        ),
        cl=_cl_input_parser.parse(
            participant_params["cl"], participant_name, network_id, registry
        ),
        cl_builder=_cl_input_parser.parse_builder(
            participant_params["cl_builder"], participant_name, network_id, registry
        ),
        name=participant_name,
        sequencer=sequencer,
    )


# Helper function to apply the sequencer logic
#
# This can only happen once all the participants have been resolved
# so it's kept in a separate function that can be chained with the top-level parsing logic
def _apply_sequencers(participants_params, network_params):
    # To avoid any null pointer references, we return early if there are no participants
    if len(participants_params) == 0:
        return participants_params

    # Now we make sure that if we specify anything explicitly, we specify everything explicitly
    #
    # No half-assed configs around here okay
    explicit_sequencers = [p.name for p in participants_params if p.sequencer != None]
    explicit_mode = len(explicit_sequencers) == len(participants_params)
    implicit_mode = len(explicit_sequencers) == 0

    if not explicit_mode and not implicit_mode:
        implicit_sequencers = [
            p.name for p in participants_params if p.name not in explicit_sequencers
        ]

        fail(
            "Invalid participants configuration on network {}: sequencers explicitly defined for nodes {} but left implicit for {}. Only fully implicit/fully explicit configurations are allowed, please either remove explicit sequencer values or complete the configuration".format(
                network_params.name,
                ",".join(explicit_sequencers),
                ",".join(implicit_sequencers),
            )
        )

    # Since copying structs is not super slick in starlark, we keep an array of just the sequencer values since we want to modify them
    #
    # TODO In the next PR a set of helper functions will be introduced to isolate the p.sequencer == p.name condition
    sequencers = [p.name for p in participants_params if p.sequencer == p.name]

    if len(sequencers) == 0:
        # If there are no participants marked as sequencers, we mark the first available one as a sequencer
        #
        # We only do this for the implicit mode though and let it fail for the explicit one
        sequencer = participants_params[0].name if implicit_mode else None

        # There always has to be at least one sequencer
        if not sequencer:
            fail(
                "Invalid sequencer configuration for network {}: could not find at least one sequencer".format(
                    network_params.name
                )
            )

        sequencers = [sequencer]

    # Now we make sure that if a participant references a particular sequencer, that sequencer exists
    participant_names = [p.name for p in participants_params]
    for p in participants_params:
        if type(p.sequencer) == "string":
            if p.sequencer not in participant_names:
                fail(
                    "Invalid sequencer value for participant {} on network {}: participant {} does not exist".format(
                        p.name, network_params.name, p.sequencer
                    )
                )

            if p.sequencer not in sequencers:
                fail(
                    "Invalid sequencer value for participant {} on network {}: participant {} is not a sequencer".format(
                        p.name, network_params.name, p.sequencer
                    )
                )

    # Now we set the sequencer explicitly for all participants that don't have one set
    #
    # For backwards compatibility, we'll use the first sequencer as the default one
    default_sequencer = _filter.first(sequencers)

    return [
        struct(
            el=p.el,
            el_builder=p.el_builder,
            cl=p.cl,
            cl_builder=p.cl_builder,
            name=p.name,
            sequencer=True
            # We set the value to true (i.e. this is a sequencer) if this node is in the list of sequencers
            #
            # We don't just check whether the p.sequencer is True since it might have been null
            # and we just selected a default sequencer
            if p.name in sequencers
            # We set the value to either an explicitly set sequencer or the default one otherwise
            else p.sequencer or default_sequencer,
        )
        for p in participants_params
    ]

    return participants_params
