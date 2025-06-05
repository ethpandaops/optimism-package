_blockscout_launcher = import_module("/src/blockscout/launcher.star")
_cl_launcher = import_module("./participant/cl/launcher.star")
_el_launcher = import_module("./participant/el/launcher.star")
_da_server_launcher = import_module("/src/da/da-server/launcher.star")
_op_batcher_launcher = import_module("/src/batcher/op-batcher/launcher.star")
_op_conductor_launcher = import_module("/src/conductor/op-conductor/launcher.star")
_op_proposer_launcher = import_module("/src/proposer/op-proposer/launcher.star")
_proxyd_launcher = import_module("/src/proxyd/launcher.star")
_rollup_boost_launcher = import_module("/src/mev/rollup-boost/launcher.star")
_tx_fuzzer_launcher = import_module("/src/tx-fuzzer/launcher.star")

_selectors = import_module("./selectors.star")
_util = import_module("/src/util.star")
_net = import_module("/src/util/net.star")


def launch(
    plan,
    params,
    supervisors_params,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
    l1_rpc_url,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    observability_helper,
):
    network_params = params.network_params
    network_name = network_params.name
    network_log_prefix = "L2 network {}".format(network_name)

    plan.print(
        "{}: Launching (network ID {})".format(
            network_log_prefix, network_params.network_id
        )
    )

    da = _launch_da_maybe(
        plan=plan, da_params=params.da_params, log_prefix=network_log_prefix
    )

    #
    # Launch CL & EL clients
    #

    participants = []

    # Here we create a selector function that will take participant params and return sequencer params for that participant
    #
    # Encpasulating the params.participants in a curried function like this seems nicer than having to pass them around
    get_sequencer_params_for = _selectors.create_get_sequencer_params_for(
        params.participants
    )

    for participant_params in params.participants:
        participant_name = participant_params.name
        participant_log_prefix = "{}: Participant {}".format(
            network_log_prefix, participant_name
        )

        plan.print("{}: Launching".format(participant_log_prefix))

        # We let the user know if this node is a sequencer
        is_sequencer = _selectors.is_sequencer(participant_params)
        if is_sequencer:
            plan.print("{}: Participant is a sequencer".format(participant_log_prefix))

        # Now we get the sequencer params
        #
        # If the node itself is a sequencer, we don't want it to refer to itself as a sequencer
        # so we pass None instead
        sequencer_params = (
            None if is_sequencer else get_sequencer_params_for(participant_params)
        )

        #
        # Launch the EL client
        #

        el_params = participant_params.el
        bootnode_contexts = [p.el.context for p in participants]

        plan.print(
            "{}: Launching EL ({})".format(participant_log_prefix, el_params.type)
        )

        el = _el_launcher.launch(
            plan=plan,
            params=el_params,
            network_params=network_params,
            sequencer_params=sequencer_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts,
            observability_helper=observability_helper,
            supervisors_params=supervisors_params,
        )

        cl_contexts = [p.cl.context for p in participants]

        #
        # Launch the builders & sidecar
        #

        sidecar_and_builders = _launch_sidecar_maybe(
            plan=plan,
            additional_services=params.additional_services,
            participant_params=participant_params,
            network_params=network_params,
            supervisors_params=supervisors_params,
            is_sequencer=is_sequencer,
            da_params=params.da_params,
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

        # We only want to add the builders we launched to the participants array
        #
        # - In case the builders are not launched at all, sidecar_and_builders will be None
        # - In case of external builders, sidecar_and_builders.el_builder/cl_builder will be None
        if sidecar_and_builders and (
            sidecar_and_builders.el_builder or sidecar_and_builders.cl_builder
        ):
            participants.append(
                struct(
                    el=sidecar_and_builders.el_builder,
                    cl=sidecar_and_builders.cl_builder,
                )
            )

        #
        # Launch the CL client
        #

        cl_params = participant_params.cl

        plan.print(
            "{}: Launching CL ({})".format(participant_log_prefix, cl_params.type)
        )

        cl = _cl_launcher.launch(
            plan=plan,
            params=cl_params,
            network_params=network_params,
            da_params=params.da_params,
            supervisors_params=supervisors_params,
            conductor_params=participant_params.conductor_params,
            is_sequencer=is_sequencer,
            el_context=sidecar_and_builders.el_builder.context
            if sidecar_and_builders and sidecar_and_builders.el_builder
            else el.context,
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

        _launch_conductor_maybe(
            plan=plan,
            participant_params=participant_params,
            network_params=network_params,
            # FIXME We might need to change the launch sequence:
            #
            # - L2s (EL,CL,builders)
            # - Supervisors
            # - Conductors
            #
            # Otherwise we cannot pass the supervisor params in
            supervisors_params=[],
            deployment_output=deployment_output,
            observability_helper=observability_helper,
            log_prefix=participant_log_prefix,
        )

        # Add the EL/CL pair to the list of launched participants
        participants.append(struct(el=el, cl=cl, name=participant_name))

    # We get a list of sequencers to be used with batcher & proposer
    sequencers_params = _selectors.get_sequencers_params(params.participants)

    _launch_batcher(
        plan=plan,
        batcher_params=params.batcher_params,
        network_params=network_params,
        sequencers_params=sequencers_params,
        deployment_output=deployment_output,
        l1_config_env_vars=l1_config_env_vars,
        da_server_context=da.context if da else None,
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
        log_prefix=participant_log_prefix,
        observability_helper=observability_helper,
    )

    _launch_proxyd_maybe(
        plan=plan,
        proxyd_params=params.proxyd_params,
        participants=participants,
        network_params=network_params,
        observability_helper=observability_helper,
        log_prefix=network_log_prefix,
    )

    _launch_tx_fuzzer_maybe(
        plan=plan,
        tx_fuzzer_params=params.tx_fuzzer_params,
        participants=participants,
        node_selectors=node_selectors,
        log_prefix=network_log_prefix,
    )

    _launch_blockscout_maybe(
        plan=plan,
        additional_services=params.additional_services,
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

    return struct(
        name=network_params.name,
        network_id=network_params.network_id,
        participants=participants,
    )


def _launch_blockscout_maybe(
    plan,
    additional_services,
    network_params,
    deployment_output,
    l1_rpc_url,
    l2_rpc_url,
    log_prefix,
):
    if "blockscout" in additional_services:
        plan.print("{}: Launching blockscout".format(log_prefix))

        _blockscout_launcher.launch(
            plan=plan,
            network_params=network_params,
            l1_rpc_url=l1_rpc_url,
            l2_rpc_url=l2_rpc_url,
            deployment_output=deployment_output,
        )

        plan.print("{}: Successfully launched blockscout".format(log_prefix))


def _launch_da_maybe(plan, da_params, log_prefix):
    if da_params:
        plan.print("{}: Launching DA".format(log_prefix))

        da = _da_server_launcher.launch(
            plan=plan,
            params=da_params,
        )

        plan.print("{}: Successfully launched DA".format(log_prefix))

        return da


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


def _launch_conductor_maybe(
    plan,
    participant_params,
    network_params,
    supervisors_params,
    deployment_output,
    observability_helper,
    log_prefix,
):
    if participant_params.conductor_params:
        if not _selectors.is_sequencer(participant_params):
            plan.print(
                "{}: Conductor is enabled for a non-sequencer node. The service will not be launched."
            )

            return

        plan.print(
            "{}: Launching conductor {}".format(
                log_prefix, participant_params.conductor_params.service_name
            )
        )

        _op_conductor_launcher.launch(
            plan=plan,
            params=participant_params.conductor_params,
            network_params=network_params,
            supervisors_params=supervisors_params,
            deployment_output=deployment_output,
            el_params=participant_params.el,
            cl_params=participant_params.cl,
            observability_helper=observability_helper,
        )

        plan.print(
            "{}: Successfully launched conductor {}".format(
                log_prefix, participant_params.conductor_params.service_name
            )
        )


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


def _launch_sidecar_maybe(
    plan,
    additional_services,
    participant_params,
    network_params,
    da_params,
    supervisors_params,
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
    # TODO Switch to the "enabled" property pattern
    if not "rollup-boost" in additional_services:
        plan.print("{}: Rollup boost not enabled, skipping launch".format(log_prefix))

        return None

    # We only launch MEV for the sequencers
    if not is_sequencer:
        plan.print(
            "{}: Rollup boost not active for non-sequencer nodes, skipping launch".format(
                log_prefix
            )
        )

        return None

    mev_params = participant_params.mev_params
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
            supervisors_params=supervisors_params,
        )
    )

    el_builder_context = (
        struct(
            ip_addr=mev_params.builder_host,
            engine_rpc_port_num=mev_params.builder_port,
            rpc_port_num=mev_params.builder_port,
            rpc_http_url=_net.service_url(
                mev_params.builder_host, _net.port(number=mev_params.builder_port)
            ),
            client_name="external-builder",
        )
        if is_external_builder
        else el_builder.context
    )

    sidecar = _launch_sidecar(
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
            supervisors_params=supervisors_params,
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

    return struct(
        el_builder=el_builder,
        cl_builder=cl_builder,
        sidecar=sidecar,
    )


def _launch_sidecar(
    plan, mev_params, network_params, sequencer_context, builder_context, jwt_file
):
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
        fail("Invalid MEV type: {}".format(mev_params.type))
