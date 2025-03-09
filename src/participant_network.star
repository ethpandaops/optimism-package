_imports = import_module("/imports.star")

_el_cl_client_launcher = _imports.load_module("src/el_cl_launcher.star")
_participant_module = _imports.load_module("src/participant.star")
_input_parser = _imports.load_module("src/package_io/input_parser.star")
_op_batcher_launcher = _imports.load_module("src/batcher/op-batcher/op_batcher_launcher.star")
_op_challenger_launcher = _imports.load_module(
    "src/challenger/op-challenger/op_challenger_launcher.star"
)
_op_proposer_launcher = _imports.load_module("src/proposer/op-proposer/op_proposer_launcher.star")
_util = _imports.load_module("src/util.star")


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
    all_el_contexts, all_cl_contexts = _el_cl_client_launcher.launch(
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

        participant_entry = _participant_module.new_participant(
            el_type,
            cl_type,
            el_context,
            cl_context,
        )

        all_participants.append(participant_entry)

    batcher_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_batcher_image = (
        batcher_params.image
        if batcher_params.image != ""
        else _input_parser.DEFAULT_BATCHER_IMAGES["op-batcher"]
    )
    _op_batcher_launcher.launch(
        plan,
        "op-batcher-{0}".format(l2_services_suffix),
        op_batcher_image,
        all_el_contexts[0],
        all_cl_contexts[0],
        l1_config_env_vars,
        batcher_key,
        batcher_params,
        network_params,
        observability_helper,
        da_server_context,
    )

    game_factory_address = _util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        ".opChainDeployments[{0}].disputeGameFactoryProxyAddress".format(l2_num),
    )
    proposer_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )
    op_proposer_image = (
        proposer_params.image
        if proposer_params.image != ""
        else _input_parser.DEFAULT_PROPOSER_IMAGES["op-proposer"]
    )
    _op_proposer_launcher.launch(
        plan,
        "op-proposer-{0}".format(l2_services_suffix),
        op_proposer_image,
        all_cl_contexts[0],
        l1_config_env_vars,
        proposer_key,
        game_factory_address,
        proposer_params,
        network_params,
        observability_helper,
    )

    return struct(
        participants=all_participants,
    )
