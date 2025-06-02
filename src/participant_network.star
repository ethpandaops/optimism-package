el_cl_client_launcher = import_module("./el_cl_launcher.star")
participant_module = import_module("./participant.star")
input_parser = import_module("./package_io/input_parser.star")
_op_batcher_launcher = import_module("./batcher/op-batcher/launcher.star")
_op_conductor_launcher = import_module("./conductor/op-conductor/launcher.star")
_op_proposer_launcher = import_module("./proposer/op-proposer/launcher.star")
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
    all_el_contexts, all_cl_contexts = el_cl_client_launcher.launch(
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
        )

        all_participants.append(participant_entry)

    _proxyd_launcher.launch(
        plan=plan,
        params=proxyd_params,
        network_params=network_params,
        observability_helper=observability_helper,
    )

    if conductor_params:
        _op_conductor_launcher.launch(
            plan=plan,
            params=conductor_params,
            network_params=network_params,
            deployment_output=deployment_output,
            el_params=struct(
                service_name=all_el_contexts[0].ip_address,
                ports={
                    _net.RPC_PORT_NAME: _net.port(
                        number=all_el_contexts[0].rpc_port_num
                    )
                },
            ),
            cl_params=struct(
                service_name=all_cl_contexts[0].ip_address,
                ports={
                    _net.HTTP_PORT_NAME: _net.port(
                        number=all_cl_contexts[0].rpc_port_num
                    )
                },
            ),
            observability_helper=observability_helper,
        )

    batcher_key = util.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )
    _op_batcher_launcher.launch(
        plan=plan,
        params=batcher_params,
        # FIXME We need to plumb the legacy args into the new format so that we make our lives easier when we're switching
        sequencers_params=[
            struct(
                el=struct(
                    service_name=all_el_contexts[0].ip_addr,
                    ports={
                        _net.RPC_PORT_NAME: _net.port(
                            number=all_el_contexts[0].rpc_port_num
                        )
                    },
                ),
                cl=struct(
                    service_name=all_cl_contexts[0].ip_addr,
                    ports={
                        _net.RPC_PORT_NAME: _net.port(
                            number=all_cl_contexts[0].http_port
                        )
                    },
                ),
                # Conductor params are not being parsed yet
                conductor_params=None,
            )
        ],
        l1_config_env_vars=l1_config_env_vars,
        gs_batcher_private_key=batcher_key,
        network_params=network_params,
        observability_helper=observability_helper,
        da_server_context=da_server_context,
    )

    # We'll grab the game factory address from the deployments
    game_factory_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .DisputeGameFactoryProxy'.format(
            util.to_hex_chain_id(network_params.network_id)
        ),
    )

    proposer_key = util.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )
    _op_proposer_launcher.launch(
        plan=plan,
        params=proposer_params,
        cl_context=all_cl_contexts[0],
        l1_config_env_vars=l1_config_env_vars,
        gs_proposer_private_key=proposer_key,
        game_factory_address=game_factory_address,
        network_params=network_params,
        observability_helper=observability_helper,
    )

    return struct(
        name=network_params.name,
        network_id=network_params.network_id,
        participants=all_participants,
    )
