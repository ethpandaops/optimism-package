el_cl_client_launcher = import_module("./el_cl_launcher.star")
participant_module = import_module("./participant.star")
input_parser = import_module("./package_io/input_parser.star")
op_batcher_launcher = import_module("./batcher/op-batcher/op_batcher_launcher.star")
op_challenger_launcher = import_module(
    "./challenger/op-challenger/op_challenger_launcher.star"
)
op_proposer_launcher = import_module("./proposer/op-proposer/op_proposer_launcher.star")
util = import_module("./util.star")


def launch_participant_network(
    plan,
    participants,
    jwt_file,
    network_params,
    batcher_params,
    challenger_params,
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
    interop_params,
    da_server_context,
):
    num_participants = len(participants)
    # First EL and sequencer CL
    all_el_contexts, all_cl_contexts = el_cl_client_launcher.launch(
        plan,
        jwt_file,
        network_params,
        mev_params,
        deployment_output,
        participants,
        num_participants,
        l1_config_env_vars,
        l2_services_suffix,
        global_log_level,
        global_node_selectors,
        global_tolerations,
        persistent,
        additional_services,
        observability_helper,
        interop_params,
        da_server_context,
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

    batcher_key = util.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_batcher_image = (
        batcher_params.image
        if batcher_params.image != ""
        else input_parser.DEFAULT_BATCHER_IMAGES["op-batcher"]
    )
    op_batcher_launcher.launch(
        plan,
        "op-batcher-{0}".format(l2_services_suffix),
        op_batcher_image,
        all_el_contexts[0],
        all_cl_contexts[0],
        l1_config_env_vars,
        batcher_key,
        batcher_params,
        observability_helper,
        da_server_context,
    )

    game_factory_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        ".opChainDeployments[{0}].disputeGameFactoryProxyAddress".format(l2_num),
    )
    challenger_key = util.read_network_config_value(
        plan,
        deployment_output,
        "challenger-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_challenger_image = (
        challenger_params.image
        if challenger_params.image != ""
        else input_parser.DEFAULT_CHALLENGER_IMAGES["op-challenger"]
    )
    op_challenger_launcher.launch(
        plan,
        "op-challenger-{0}".format(l2_services_suffix),
        op_challenger_image,
        all_el_contexts[0],
        all_cl_contexts[0],
        l1_config_env_vars,
        challenger_key,
        game_factory_address,
        deployment_output,
        network_params,
        challenger_params,
        observability_helper,
    )

    proposer_key = util.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_proposer_image = (
        proposer_params.image
        if proposer_params.image != ""
        else input_parser.DEFAULT_PROPOSER_IMAGES["op-proposer"]
    )
    op_proposer_launcher.launch(
        plan,
        "op-proposer-{0}".format(l2_services_suffix),
        op_proposer_image,
        all_cl_contexts[0],
        l1_config_env_vars,
        proposer_key,
        game_factory_address,
        proposer_params,
        observability_helper,
    )

    return all_participants
