el_cl_client_launcher = import_module("./el_cl_launcher.star")
participant_module = import_module("./participant.star")
input_parser = import_module("./package_io/input_parser.star")
op_batcher_launcher = import_module("./batcher/op-batcher/op_batcher_launcher.star")
op_challenger_launcher = import_module(
    "./challenger/op-challenger/op_challenger_launcher.star"
)
op_proposer_launcher = import_module("./proposer/op-proposer/op_proposer_launcher.star")
op_signer_launcher = import_module("./signer/op_signer_launcher.star")
proxyd_launcher = import_module("./proxyd/proxyd_launcher.star")
util = import_module("./util.star")


def launch_participant_network(
    plan,
    chain_args,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
    l2_num,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    observability_helper,
    interop_params,
    da_server_context,
):
    participants = chain_args.participants
    network_params = chain_args.network_params
    batcher_params = chain_args.batcher_params
    proposer_params = chain_args.proposer_params
    challenger_params = chain_args.challenger_params
    conductor_params = chain_args.conductor_params
    # First EL and sequencer CL
    all_el_contexts, all_cl_contexts, conductor_contexts = el_cl_client_launcher.launch(
        plan,
        network_params,
        chain_args.mev_params,
        interop_params,
        jwt_file,
        deployment_output,
        participants,
        l1_config_env_vars,
        network_params.name,
        da_server_context,
        chain_args.additional_services,
        global_log_level,
        global_node_selectors,
        global_tolerations,
        persistent,
        observability_helper,
        conductor_params,
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
        chain_args.proxyd_params,
        network_params,
        all_el_contexts,
        observability_helper,
    )

    # signer needs to start before its clients
    signer_context = op_signer_launcher.launch(
        plan,
        chain_args.signer_params,
        network_params,
        deployment_output,
        {
            op_batcher_launcher.SERVICE_TYPE: op_batcher_launcher.SERVICE_NAME,
            op_proposer_launcher.SERVICE_TYPE: op_proposer_launcher.SERVICE_NAME,
            op_challenger_launcher.SERVICE_TYPE: op_challenger_launcher.SERVICE_NAME
            if challenger_params.enabled
            else None,
        },
        observability_helper,
    )

    batcher_service = op_batcher_launcher.launch(
        plan,
        all_el_contexts[0],
        all_cl_contexts[0],
        l1_config_env_vars,
        signer_context,
        batcher_params,
        network_params,
        observability_helper,
        da_server_context,
        conductor_contexts,
    )

    game_factory_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        ".opChainDeployments[{0}].disputeGameFactoryProxyAddress".format(l2_num),
    )
    proposer_service = op_proposer_launcher.launch(
        plan,
        all_cl_contexts[0],
        l1_config_env_vars,
        signer_context,
        game_factory_address,
        proposer_params,
        network_params,
        observability_helper,
        conductor_contexts,
    )

    if challenger_params.enabled:
        op_challenger_launcher.launch(
            plan,
            all_el_contexts[0],
            all_cl_contexts[0],
            l1_config_env_vars,
            signer_context,
            game_factory_address,
            deployment_output,
            network_params,
            challenger_params,
            interop_params,
            observability_helper,
        )

    return struct(
        participants=all_participants,
    )
