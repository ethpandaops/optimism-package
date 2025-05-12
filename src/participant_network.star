el_cl_client_launcher = import_module("./el_cl_launcher.star")
participant_module = import_module("./participant.star")
input_parser = import_module("./package_io/input_parser.star")
op_batcher_launcher = import_module("./batcher/op-batcher/op_batcher_launcher.star")
op_proposer_launcher = import_module("./proposer/op-proposer/op_proposer_launcher.star")
proxyd_launcher = import_module("./proxyd/proxyd_launcher.star")
util = import_module("./util.star")
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
    deployment_output,
    l1_config_env_vars,
    l2_num,
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
    all_el_contexts, all_cl_contexts = el_cl_client_launcher.launch(
        plan=plan,
        jwt_file=jwt_file,
        network_params=network_params,
        mev_params=mev_params,
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
        )

        all_participants.append(participant_entry)

    proxyd_launcher.launch(
        plan,
        proxyd_params,
        network_params,
        all_el_contexts,
        observability_helper,
    )

    batcher_key = util.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_batcher_launcher.launch(
        plan,
        "op-batcher-{0}".format(l2_services_suffix),
        batcher_params.image or registry.get(_registry.OP_BATCHER),
        all_el_contexts[0],
        all_cl_contexts[0],
        l1_config_env_vars,
        batcher_key,
        batcher_params,
        network_params,
        observability_helper,
        da_server_context,
    )

    game_factory_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        ".opChainDeployments[{0}].DisputeGameFactoryProxy".format(l2_num),
    )
    proposer_key = util.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_proposer_launcher.launch(
        plan,
        "op-proposer-{0}".format(l2_services_suffix),
        proposer_params.image or registry.get(_registry.OP_PROPOSER),
        all_cl_contexts[0],
        l1_config_env_vars,
        proposer_key,
        game_factory_address,
        proposer_params,
        network_params,
        observability_helper,
    )

    return struct(
        name=network_params.name,
        network_id=network_params.network_id,
        participants=all_participants,
    )
