_blockscout_launcher = import_module("/src/blockscout/launcher.star")
_op_batcher_launcher = import_module("/src/batcher/op-batcher/launcher.star")
_op_conductor_launcher = import_module("/src/conductor/op-conductor/launcher.star")
_op_proposer_launcher = import_module("/src/proposer/op-proposer/launcher.star")
_proxyd_launcher = import_module("/src/proxyd/launcher.star")
_tx_fuzzer_launcher = import_module("/src/tx-fuzzer/launcher.star")
_op_conductor_ops_launcher = import_module(
    "/src/conductor/op-conductor-ops/launcher.star"
)
_flashblocks_websocket_proxy_launcher = import_module("/src/flashblocks/flashblocks-websocket-proxy/launcher.star")

_selectors = import_module("./selectors.star")
_util = import_module("/src/util.star")
_net = import_module("/src/util/net.star")
_filter = import_module("/src/util/filter.star")


def launch(
    plan,
    params,
    supervisors_params,
    original_launcher_output__hack,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
    l1_rpc_url,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    observability_helper,
    registry,
):
    network_params = params.network_params
    network_name = network_params.name
    network_log_prefix = "L2 network {}".format(network_name)

    plan.print(
        "{}: Launching (network ID {})".format(
            network_log_prefix, network_params.network_id
        )
    )

    # Collect conductor contexts for flashblocks proxy
    conductor_contexts = []
    
    # Only process participants that were actually launched (not flashblocks participants)
    # The original_launcher_output__hack.participants contains only the regular participants
    for index_hack, launched_participant in enumerate(original_launcher_output__hack.participants):
        participant_name = launched_participant.name
        participant_log_prefix = "{}: Participant {}".format(
            network_log_prefix, participant_name
        )

        plan.print("{}: Launching conductor".format(participant_log_prefix))

        # Find the matching participant params from the original params
        participant_params = None
        for p in params.participants:
            if p.name == participant_name:
                participant_params = p
                break

        if participant_params == None:
            fail("Could not find participant params for {}".format(participant_name))

        conductor_context = _launch_conductor_maybe(
            plan=plan,
            participant_params=participant_params,
            network_params=network_params,
            supervisors_params=supervisors_params,
            sidecar_context=launched_participant.sidecar.context
            if launched_participant.sidecar
            else None,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
            log_prefix=participant_log_prefix,
        )
        
        # Collect conductor contexts for flashblocks proxy
        if conductor_context:
            conductor_contexts.append(conductor_context.context)

    # Launch flashblocks services early so they exist even if conductor bootstrap later fails
    flashblocks_websocket_proxy_context = _launch_flashblocks_maybe(
        plan=plan,
        params=params,
        original_launcher_output__hack=original_launcher_output__hack,
        conductor_contexts=conductor_contexts,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level=log_level,
        persistent=persistent,
        tolerations=tolerations,
        node_selectors=node_selectors,
        observability_helper=observability_helper,
        log_prefix=network_log_prefix,
    )

    # Launch participants that need flashblocks with the websocket proxy URL
    _launch_flashblocks_participants(
        plan=plan,
        params=params,
        original_launcher_output__hack=original_launcher_output__hack,
        flashblocks_websocket_proxy_context=flashblocks_websocket_proxy_context,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        l1_config_env_vars=l1_config_env_vars,
        log_level=log_level,
        persistent=persistent,
        tolerations=tolerations,
        node_selectors=node_selectors,
        observability_helper=observability_helper,
        log_prefix=network_log_prefix,
    )

    # We now bootstrap the conductor cluster (may fail without preventing flashblocks from launching)
    _op_conductor_ops_launcher.launch(
        plan=plan,
        l2_params=params,
        registry=registry,
    )

    # We get a list of sequencers to be used with batcher & proposer
    sequencers_params = _selectors.get_sequencers_params(params.participants)

    _launch_batcher(
        plan=plan,
        batcher_params=params.batcher_params,
        network_params=network_params,
        sequencers_params=sequencers_params,
        deployment_output=deployment_output,
        l1_config_env_vars=l1_config_env_vars,
        da_server_context=original_launcher_output__hack.da.context
        if original_launcher_output__hack.da
        else None,
        observability_helper=observability_helper,
        log_prefix=network_log_prefix,
    )

    _launch_proposer(
        plan=plan,
        proposer_params=params.proposer_params,
        network_params=network_params,
        sequencers_params=sequencers_params,
        deployment_output=deployment_output,
        l1_config_env_vars=l1_config_env_vars,
        log_prefix=network_log_prefix,
        observability_helper=observability_helper,
    )

    _launch_proxyd_maybe(
        plan=plan,
        proxyd_params=params.proxyd_params,
        participants=original_launcher_output__hack.participants,
        network_params=network_params,
        observability_helper=observability_helper,
        log_prefix=network_log_prefix,
    )

    _launch_tx_fuzzer_maybe(
        plan=plan,
        tx_fuzzer_params=params.tx_fuzzer_params,
        participants=original_launcher_output__hack.participants,
        node_selectors=node_selectors,
        log_prefix=network_log_prefix,
    )

    _launch_blockscout_maybe(
        plan=plan,
        blockscout_params=params.blockscout_params,
        network_params=network_params,
        l1_rpc_url=l1_rpc_url,
        l2_rpc_url=_net.service_url(
            params.participants[0].el.service_name,
            params.participants[0].el.ports[_net.RPC_PORT_NAME],
        ),
        deployment_output=deployment_output,
        log_prefix=network_log_prefix,
    )

    network_id_as_hex = _util.to_hex_chain_id(network_params.network_id)
    l1_bridge_address = _util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .L1StandardBridgeProxy'.format(
            network_id_as_hex
        ),
    )

    plan.print("{}: Complete".format(network_log_prefix))
    plan.print(
        "{}: Begin your L2 adventures by depositing some L1 Kurtosis ETH to: {}".format(
            network_log_prefix, l1_bridge_address
        )
    )


def _launch_blockscout_maybe(
    plan,
    blockscout_params,
    network_params,
    deployment_output,
    l1_rpc_url,
    l2_rpc_url,
    log_prefix,
):
    if blockscout_params:
        plan.print("{}: Launching blockscout".format(log_prefix))

        _blockscout_launcher.launch(
            plan=plan,
            params=blockscout_params,
            network_params=network_params,
            l1_rpc_url=l1_rpc_url,
            l2_rpc_url=l2_rpc_url,
            deployment_output=deployment_output,
        )

        plan.print("{}: Successfully launched blockscout".format(log_prefix))


def _launch_proxyd_maybe(
    plan, proxyd_params, participants, network_params, observability_helper, log_prefix
):
    if proxyd_params:
        plan.print("{}: Launching proxyd".format(log_prefix))

        _proxyd_launcher.launch(
            plan=plan,
            params=proxyd_params,
            network_params=network_params,
            observability_helper=observability_helper,
        )

        plan.print("{}: Successfully launched proxyd".format(log_prefix))


def _launch_batcher(
    plan,
    batcher_params,
    sequencers_params,
    network_params,
    deployment_output,
    l1_config_env_vars,
    observability_helper,
    da_server_context,
    log_prefix,
):
    plan.print("{}: Launching batcher".format(log_prefix))

    batcher_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )

    return _op_batcher_launcher.launch(
        plan=plan,
        params=batcher_params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=l1_config_env_vars,
        gs_batcher_private_key=batcher_key,
        network_params=network_params,
        observability_helper=observability_helper,
        da_server_context=da_server_context,
    )

    plan.print("{}: Successfully launched batcher".format(log_prefix))


def _launch_proposer(
    plan,
    proposer_params,
    network_params,
    sequencers_params,
    deployment_output,
    l1_config_env_vars,
    observability_helper,
    log_prefix,
):
    plan.print(
        "{}: Launching proposer {}".format(log_prefix, proposer_params.service_name)
    )

    # We'll grab the game factory address from the deployments
    game_factory_address = _util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .DisputeGameFactoryProxy'.format(
            _util.to_hex_chain_id(network_params.network_id)
        ),
    )

    proposer_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )

    _op_proposer_launcher.launch(
        plan=plan,
        params=proposer_params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=l1_config_env_vars,
        gs_proposer_private_key=proposer_key,
        game_factory_address=game_factory_address,
        network_params=network_params,
        observability_helper=observability_helper,
    )

    plan.print(
        "{}: Successfully launched proposer {}".format(
            log_prefix, proposer_params.service_name
        )
    )


def _launch_tx_fuzzer_maybe(
    plan, tx_fuzzer_params, participants, node_selectors, log_prefix
):
    if tx_fuzzer_params:
        plan.print(
            "{}: Launching tx fuzzer {}".format(
                log_prefix, tx_fuzzer_params.service_name
            )
        )

        _tx_fuzzer_launcher.launch(
            plan=plan,
            params=tx_fuzzer_params,
            # FIXME
            el_context=participants[0].el.context,
            node_selectors=node_selectors,
        )

        plan.print(
            "{}: Successfully launched tx fuzzer {}".format(
                log_prefix, tx_fuzzer_params.service_name
            )
        )


def _launch_conductor_maybe(
    plan,
    participant_params,
    network_params,
    supervisors_params,
    sidecar_context,
    deployment_output,
    observability_helper,
    log_prefix,
):
    if participant_params.conductor_params:
        if not _selectors.is_sequencer(participant_params):
            plan.print(
                "{}: Conductor is enabled for a non-sequencer node. The service will not be launched."
            )

            return None

        plan.print(
            "{}: Launching conductor {}".format(
                log_prefix, participant_params.conductor_params.service_name
            )
        )

        conductor_result = _op_conductor_launcher.launch(
            plan=plan,
            params=participant_params.conductor_params,
            network_params=network_params,
            supervisors_params=supervisors_params,
            sidecar_context=sidecar_context,
            deployment_output=deployment_output,
            el_params=participant_params.el,
            cl_params=participant_params.cl,
            builder_el_params=participant_params.el_builder,
            observability_helper=observability_helper,
        )

        plan.print(
            "{}: Successfully launched conductor {}".format(
                log_prefix, participant_params.conductor_params.service_name
            )
        )
        
        return conductor_result
    
    return None


def _launch_flashblocks_maybe(
    plan,
    params,
    original_launcher_output__hack,
    conductor_contexts,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    observability_helper,
    log_prefix,
):
    websocket_proxy_params = params.flashblocks_websocket_proxy_params

    if not websocket_proxy_params:
        plan.print("{}: No flashblocks websocket proxy to launch".format(log_prefix))
        return None

    plan.print(
        "{}: Launching flashblocks websocket proxy {}".format(
            log_prefix, websocket_proxy_params.service_name
        )
    )

    websocket_proxy_context = _flashblocks_websocket_proxy_launcher.launch(
        plan=plan,
        params=websocket_proxy_params,
        conductors_contexts=conductor_contexts,
        observability_helper=observability_helper,
    )

    plan.print(
        "{}: Successfully launched flashblocks websocket proxy {}".format(
            log_prefix, websocket_proxy_params.service_name
        )
    )

    return websocket_proxy_context


def _launch_flashblocks_participants(
    plan,
    params,
    original_launcher_output__hack,
    flashblocks_websocket_proxy_context,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    observability_helper,
    log_prefix,
):
    if not flashblocks_websocket_proxy_context:
        plan.print("{}: No flashblocks websocket proxy available, skipping flashblocks participants".format(log_prefix))
        return

    websocket_url = flashblocks_websocket_proxy_context.context.ws_url + "/ws"
    
    # Get the flashblocks participants that were deferred from the original launch
    flashblocks_participants = original_launcher_output__hack.flashblocks_participants
    
    if not flashblocks_participants:
        plan.print("{}: No flashblocks participants to launch".format(log_prefix))
        return

    plan.print("{}: Launching {} flashblocks participants with websocket URL: {}".format(
        log_prefix, len(flashblocks_participants), websocket_url
    ))

    _el_launcher = import_module("/src/el/launcher.star") 
    _cl_launcher = import_module("/src/cl/launcher.star")
    _selectors = import_module("./selectors.star")
    
    get_sequencer_params_for = _selectors.create_get_sequencer_params_for(params.participants)

    bootnode_contexts = [p.el.context for p in original_launcher_output__hack.participants]
    cl_contexts = [p.cl.context for p in original_launcher_output__hack.participants]

    for participant_params in flashblocks_participants:
        participant_name = participant_params.name
        participant_log_prefix = "{}: Flashblocks Participant {}".format(log_prefix, participant_name)

        # Only op-reth supports flashblocks
        if participant_params.el.type != "op-reth":
            plan.print(
                "{}: Skipping {} - only op-reth supports flashblocks (type: {})".format(
                    participant_log_prefix, participant_name, participant_params.el.type
                )
            )
            continue

        plan.print("{}: Launching with flashblocks websocket URL".format(participant_log_prefix))

        is_sequencer = _selectors.is_sequencer(participant_params)
        sequencer_params = None if is_sequencer else get_sequencer_params_for(participant_params)

        plan.print("{}: Launching EL ({}) with flashblocks".format(participant_log_prefix, participant_params.el.type))

        el = _el_launcher.launch(
            plan=plan,
            params=participant_params.el,
            network_params=params.network_params,
            sequencer_params=sequencer_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts,
            observability_helper=observability_helper,
            supervisors_params=[],
            websocket_url=websocket_url,
        )

        sidecar_and_builders = _launch_flashblocks_sidecar_maybe(
            plan=plan,
            participant_params=participant_params,
            network_params=params.network_params,
            da_params=params.da_params,
            is_sequencer=is_sequencer,
            el_context=el.context,
            cl_contexts=cl_contexts,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts,
            observability_helper=observability_helper,
            log_prefix=participant_log_prefix,
        )

        plan.print("{}: Launching CL ({})".format(participant_log_prefix, participant_params.cl.type))

        el_context_for_cl = (
            sidecar_and_builders.sidecar.context if sidecar_and_builders and sidecar_and_builders.sidecar
            else el.context
        )

        cl = _cl_launcher.launch(
            plan=plan,
            params=participant_params.cl,
            network_params=params.network_params,
            da_params=params.da_params,
            supervisors_params=[],
            conductor_params=None,
            is_sequencer=is_sequencer,
            el_context=el_context_for_cl,
            cl_contexts=cl_contexts,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )

        mev_status = "with MEV (rollup-boost)" if sidecar_and_builders and sidecar_and_builders.sidecar else "without MEV"
        plan.print("{}: Successfully launched with --websocket-url={} {}".format(
            participant_log_prefix, websocket_url, mev_status
        ))

        bootnode_contexts.append(el.context)
        cl_contexts.append(cl.context)


def _launch_flashblocks_sidecar_maybe(
    plan,
    participant_params,
    network_params,
    da_params,
    is_sequencer,
    el_context,
    cl_contexts,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    bootnode_contexts,
    observability_helper,
    log_prefix,
):
    """Launch MEV sidecar (rollup-boost + rbuilder) for flashblocks participants if configured."""
    
    _el_launcher = import_module("/src/el/launcher.star") 
    _cl_launcher = import_module("/src/cl/launcher.star")
    _rollup_boost_launcher = import_module("/src/mev/rollup-boost/launcher.star")
    _selectors = import_module("./selectors.star")
    
    mev_params = participant_params.mev_params
    if not mev_params:
        plan.print("{}: MEV/rollup-boost not enabled, skipping sidecar launch".format(log_prefix))
        return None

    if not is_sequencer:
        plan.print(
            "{}: MEV/rollup-boost not active for non-sequencer nodes, skipping sidecar launch".format(
                log_prefix
            )
        )
        return None

    plan.print("{}: Launching MEV sidecar (rollup-boost + rbuilder)".format(log_prefix))

    el_builder_params = participant_params.el_builder
    cl_builder_params = participant_params.cl_builder

    is_external_builder = mev_params.builder_host and mev_params.builder_port
    if is_external_builder:
        plan.print(
            "{}: External EL builder specified - EL/CL builders will not be launched".format(
                log_prefix
            )
        )

    el_builder = (
        None
        if is_external_builder
        else _el_launcher.launch(
            plan=plan,
            params=el_builder_params,
            network_params=network_params,
            sequencer_params=participant_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts,
            observability_helper=observability_helper,
            supervisors_params=[],
        )
    )

    el_builder_context = (
        struct(
            ip_addr=mev_params.builder_host,
            engine_rpc_port_num=mev_params.builder_port,
            rpc_port_num=mev_params.builder_port,
            rpc_http_url="http://{}:{}".format(mev_params.builder_host, mev_params.builder_port),
            client_name="external-builder",
        )
        if is_external_builder
        else el_builder.context
    )

    sidecar = _launch_flashblocks_sidecar(
        plan=plan,
        mev_params=mev_params,
        network_params=network_params,
        sequencer_context=el_context,
        builder_context=el_builder_context,
        jwt_file=jwt_file,
    )

    cl_builder = (
        None
        if is_external_builder
        else _cl_launcher.launch(
            plan=plan,
            params=cl_builder_params,
            network_params=network_params,
            da_params=da_params,
            supervisors_params=[],
            conductor_params=None,
            is_sequencer=True,
            el_context=el_builder_context,
            cl_contexts=cl_contexts,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )
    )

    plan.print("{}: Successfully launched MEV sidecar".format(log_prefix))

    return struct(
        el_builder=el_builder,
        cl_builder=cl_builder,
        sidecar=sidecar,
    )


def _launch_flashblocks_sidecar(
    plan, mev_params, network_params, sequencer_context, builder_context, jwt_file
):
    """Launch the rollup-boost sidecar for flashblocks participants."""
    _rollup_boost_launcher = import_module("/src/mev/rollup-boost/launcher.star")
    
    if mev_params.type == "rollup-boost":
        return _rollup_boost_launcher.launch(
            plan=plan,
            params=mev_params,
            network_params=network_params,
            sequencer_context=sequencer_context,
            builder_context=builder_context,
            jwt_file=jwt_file,
        )
    else:
        fail("Invalid MEV type for flashblocks: {}".format(mev_params.type))
