_op_batcher_launcher = import_module("./batcher/op-batcher/launcher.star")
_op_conductor_launcher = import_module("./conductor/op-conductor/launcher.star")
_op_conductor_ops_launcher = import_module("./conductor/op-conductor-ops/launcher.star")
_op_proposer_launcher = import_module("./proposer/op-proposer/launcher.star")
util = import_module("./util.star")
_net = import_module("/src/util/net.star")
_registry = import_module("./package_io/registry.star")


def launch_participant_network__hack(
    original_participant_network_output__hack,
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
    # In the legacy setup the first node is always the sequencer
    sequencer_participant = original_participant_network_output__hack.participants[0]
    sequencer_params = struct(
        name="sequencer",
        sequencer="sequencer",
        el=struct(
            service_name=sequencer_participant.el_context.ip_addr,
            ports={
                _net.RPC_PORT_NAME: _net.port(
                    number=sequencer_participant.el_context.rpc_port_num
                )
            },
        ),
        cl=struct(
            service_name=sequencer_participant.cl_context.ip_addr,
            ports={
                _net.RPC_PORT_NAME: _net.port(
                    number=sequencer_participant.cl_context.http_port
                )
            },
        ),
        conductor_params=conductor_params,
    )

    conductor_context = (
        _op_conductor_launcher.launch(
            plan=plan,
            params=conductor_params,
            network_params=network_params,
            deployment_output=deployment_output,
            # FIXME We need to plumb the legacy args into the new format so that we make our lives easier when we're switching
            el_params=sequencer_params.el,
            cl_params=sequencer_params.cl,
            observability_helper=observability_helper,
            supervisors_params=supervisors_params,
            # Sidecar context is now deeply buried in the el_cl_launcher output
            # and we cannot dig it out without risking breaking well everything
            #
            # FIXME After refactoring, this should be passed in
            sidecar_context=None,
        ).context
        if conductor_params
        else None
    )

    _op_conductor_ops_launcher.launch(
        plan=plan,
        l2_params=struct(
            participants=[sequencer_params],
            network_params=network_params,
        ),
        registry=registry,
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
        sequencers_params=sequencers_params,
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
        cl_context=sequencer_participant.cl_context,
        l1_config_env_vars=l1_config_env_vars,
        gs_proposer_private_key=proposer_key,
        game_factory_address=game_factory_address,
        network_params=network_params,
        observability_helper=observability_helper,
    )
