el_cl_client_launcher = import_module("./el_cl_launcher.star")
participant_module = import_module("./participant.star")
input_parser = import_module("./package_io/input_parser.star")
_proxyd_launcher = import_module("./proxyd/launcher.star")
util = import_module("./util.star")
_net = import_module("/src/util/net.star")
_registry = import_module("./package_io/registry.star")


def launch_participant_network(
    plan,
    participants,
    jwt_file,
    network_params,
    proxyd_params,
    batcher_params,
    proposer_params,
    mev_params,
    conductor_params,
    deployment_output,
    l1_config_env_vars,
    l2_services_suffix,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    additional_services,
    observability_helper,
    supervisors_params,
    da_server_context,
    registry=_registry.Registry(),
):
    num_participants = len(participants)

    # First EL and sequencer CL
    (
        all_el_contexts,
        all_cl_contexts,
        sidecar_context__hack,
    ) = el_cl_client_launcher.launch(
        plan=plan,
        jwt_file=jwt_file,
        network_params=network_params,
        mev_params=mev_params,
        conductor_params=conductor_params,
        deployment_output=deployment_output,
        participants=participants,
        num_participants=num_participants,
        l1_config_env_vars=l1_config_env_vars,
        l2_services_suffix=l2_services_suffix,
        global_log_level=global_log_level,
        global_node_selectors=global_node_selectors,
        global_tolerations=global_tolerations,
        persistent=persistent,
        additional_services=additional_services,
        observability_helper=observability_helper,
        supervisors_params=supervisors_params,
        da_server_context=da_server_context,
        registry=registry,
    )

    all_participants = []
    for index, participant in enumerate(participants):
        el_type = participant.el_type
        cl_type = participant.cl_type

        el_context = all_el_contexts[index]
        cl_context = all_cl_contexts[index]

        participant_entry = participant_module.new_participant(
            el_type,
            cl_type,
            el_context,
            cl_context,
            # We only add the sidecar context for the first participant (the sequencer)
            #
            # FIXME Kill this with fire
            sidecar_context=sidecar_context__hack if index == 0 else None,
        )

        all_participants.append(participant_entry)

    _proxyd_launcher.launch(
        plan=plan,
        params=proxyd_params,
        network_params=network_params,
        observability_helper=observability_helper,
    )

    return struct(
        name=network_params.name,
        network_id=network_params.network_id,
        participants=all_participants,
        da_server_context__hack=da_server_context,
    )
