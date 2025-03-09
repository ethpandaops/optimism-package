_imports = import_module("/imports.star")

_participant_network = _imports.load_module("src/participant_network.star")
_blockscout = _imports.load_module("src/blockscout/blockscout_launcher.star")
_da_server_launcher = _imports.load_module("src/alt-da/da-server/da_server_launcher.star")
_util = _imports.load_module("src/util.star")


def launch_l2(
    plan,
    l2_num,
    l2_services_suffix,
    l2_args,
    jwt_file,
    deployment_output,
    l1_config,
    l1_rpc_url,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    observability_helper,
    interop_params,
):
    network_params = l2_args.network_params
    batcher_params = l2_args.batcher_params
    proposer_params = l2_args.proposer_params
    mev_params = l2_args.mev_params

    plan.print("Deploying L2 with name {0}".format(network_params.name))

    # we need to launch da-server before launching the participant network
    # because op-batcher and op-node(s) need to know the da-server url, if present
    da_server_context = _da_server_launcher.disabled_da_server_context()
    if "da_server" in l2_args.additional_services:
        da_server_image = l2_args.da_server_params.image
        plan.print("Launching da-server")
        da_server_context = _da_server_launcher.launch_da_server(
            plan,
            "da-server-{0}".format(l2_services_suffix),
            da_server_image,
            l2_args.da_server_params.cmd,
        )
        plan.print("Successfully launched da-server")

    l2 = _participant_network.launch_participant_network(
        plan=plan,
        participants=l2_args.participants,
        jwt_file=jwt_file,
        network_params=network_params,
        batcher_params=batcher_params,
        proposer_params=proposer_params,
        mev_params=mev_params,
        deployment_output=deployment_output,
        l1_config_env_vars=l1_config,
        l2_num=l2_num,
        l2_services_suffix=l2_services_suffix,
        global_log_level=global_log_level,
        global_node_selectors=global_node_selectors,
        global_tolerations=global_tolerations,
        persistent=persistent,
        additional_services=l2_args.additional_services,
        observability_helper=observability_helper,
        interop_params=interop_params,
        da_server_context=da_server_context,
    )

    all_el_contexts = []
    all_cl_contexts = []
    for participant in l2.participants:
        all_el_contexts.append(participant.el_context)
        all_cl_contexts.append(participant.cl_context)

    network_id_as_hex = _util.to_hex_chain_id(network_params.network_id)
    l1_bridge_address = _util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .l1StandardBridgeProxyAddress'.format(
            network_id_as_hex
        ),
    )

    for additional_service in l2_args.additional_services:
        if additional_service == "blockscout":
            plan.print("Launching op-blockscout")
            _blockscout.launch_blockscout(
                plan,
                l2_services_suffix,
                l1_rpc_url,
                all_el_contexts[0],  # first l2 EL url
                network_params.name,
                deployment_output,
                network_params.network_id,
            )
            plan.print("Successfully launched op-blockscout")

    plan.print(l2.participants)
    plan.print(
        "Begin your L2 adventures by depositing some L1 Kurtosis ETH to: {0}".format(
            l1_bridge_address
        )
    )

    return l2
