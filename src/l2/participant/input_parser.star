_registry = import_module("/src/package_io/registry.star")
_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")
_selectors = import_module("/src/l2/selectors.star")

_el_input_parser = import_module("./el/input_parser.star")
_cl_input_parser = import_module("./cl/input_parser.star")
_mev_input_parser = import_module("/src/mev/input_parser.star")
_conductor_input_parser = import_module("/src/conductor/input_parser.star")

_DEFAULT_ARGS = {
    "el": None,
    "el_builder": None,
    "cl": None,
    "cl_builder": None,
    "sequencer": None,
    "mev_params": None,
    "conductor_params": None,
}


def parse(args, network_params, registry):
    participant_index_generator = _id.autoincrement(initial=0)

    participants_params = _filter.remove_none(
        [
            _parse_instance(
                participant_args=participant_args or {},
                participant_name=participant_name,
                participant_index_generator=participant_index_generator,
                network_params=network_params,
                registry=registry,
            )
            for participant_name, participant_args in (args or {}).items()
        ]
    )

    if len(participants_params) == 0:
        fail(
            "Invalid participants configuration for network {}: at least one participant must be defined".format(
                network_params.name
            )
        )

    participants_params = _assert_conductors(
        participants_params=participants_params,
        network_params=network_params,
    )

    participants_params = _apply_sequencers(
        participants_params=participants_params,
        network_params=network_params,
    )

    return participants_params


def _parse_instance(
    participant_args,
    participant_name,
    participant_index_generator,
    network_params,
    registry,
):
    network_id = network_params.network_id
    network_name = network_params.name

    # To bridge the legacy list format to the new dictionary format for participants,
    # we introduce an index label
    #
    # This will be added to the EL/CL labels so that the optimism devent SDK can extract the legacy node index
    participant_index = participant_index_generator()

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
    _id.assert_id(
        id=participant_name, name="Name of the node on network {}".format(network_name)
    )

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

    # We add the MEV
    #
    # TODO MEV only makes sense for the sequencer node so we should decide how to handle this,
    # whether to log & ignore or fail
    mev_params = _mev_input_parser.parse(
        mev_args=participant_params["mev_params"],
        network_params=network_params,
        participant_name=participant_name,
        participant_index=participant_index,
        registry=registry,
    )

    # We add the conductor
    #
    # TODO Conductor only makes sense for the sequencer node so we should decide how to handle this,
    # whether to log & ignore or fail
    conductor_params = _conductor_input_parser.parse(
        conductor_args=participant_params["conductor_params"],
        network_params=network_params,
        participant_name=participant_name,
        participant_index=participant_index,
        registry=registry,
    )

    return struct(
        el=_el_input_parser.parse(
            el_args=participant_params["el"],
            participant_name=participant_name,
            participant_index=participant_index,
            network_params=network_params,
            registry=registry,
        ),
        el_builder=_el_input_parser.parse_builder(
            el_args=participant_params["el_builder"],
            participant_name=participant_name,
            participant_index=participant_index,
            network_params=network_params,
            registry=registry,
        ),
        cl=_cl_input_parser.parse(
            cl_args=participant_params["cl"],
            participant_name=participant_name,
            participant_index=participant_index,
            network_params=network_params,
            registry=registry,
        ),
        cl_builder=_cl_input_parser.parse_builder(
            cl_args=participant_params["cl_builder"],
            participant_name=participant_name,
            participant_index=participant_index,
            network_params=network_params,
            registry=registry,
        ),
        name=participant_name,
        index=participant_index,
        sequencer=sequencer,
        mev_params=mev_params,
        conductor_params=conductor_params,
    )


# Helper function to apply the sequencer logic
#
# This can only happen once all the participants have been resolved
# so it's kept in a separate function that can be chained with the top-level parsing logic
def _apply_sequencers(participants_params, network_params):
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
    sequencers = [p.name for p in _selectors.get_sequencers_params(participants_params)]

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
            sequencer=p.name
            # We set the value to the name of node itself (i.e. this is a sequencer) if this node is in the list of sequencers
            #
            # We don't just check whether the p.sequencer is True since it might have been null
            # and we just selected a default sequencer
            if p.name in sequencers
            # We set the value to either an explicitly set sequencer or the default one otherwise
            else p.sequencer or default_sequencer,
            mev_params=p.mev_params,
            conductor_params=p.conductor_params,
        )
        for p in participants_params
    ]

    return participants_params


# Helper function that ensures that if there are conductors present, we have at least two participants defined
#
# This is needed since a conductor needs to have at least one peer (see OP_CONDUCTOR_HEALTHCHECK_MIN_PEER_COUNT)
def _assert_conductors(participants_params, network_params):
    has_conductors = any([p.conductor_params for p in participants_params])

    if not has_conductors:
        return participants_params

    if len(participants_params) == 1:
        fail(
            "Invalid participants configuration for network {}: at least two participants must be defined if conductors are present".format(
                network_params.name
            )
        )

    return participants_params
