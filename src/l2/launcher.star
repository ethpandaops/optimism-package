_cl_launcher = import_module("/src/cl/launcher.star")
_el_launcher = import_module("/src/el/launcher.star")
_da_server_launcher = import_module("/src/da/da-server/launcher.star")
_op_signer_launcher = import_module("/src/signer/op-signer/launcher.star")
_rollup_boost_launcher = import_module("/src/mev/rollup-boost/launcher.star")

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

    da = _launch_da_maybe(
        plan=plan, da_params=params.da_params, log_prefix=network_log_prefix
    )

    # We'll need batcher private key for the batcher as well as for the signer
    batcher_private_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "batcher-{0}".format(network_params.network_id),
        ".privateKey",
    )

    # We'll need proposer private key for the proposer as well as for the signer
    proposer_private_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "proposer-{0}".format(network_params.network_id),
        ".privateKey",
    )

    sequencer_private_key = _util.read_network_config_value(
        plan,
        deployment_output,
        "sequencer-{0}".format(network_params.network_id),
        ".privateKey",
    )

    signer = _launch_signer_maybe(
        plan=plan,
        signer_params=params.signer_params,
        network_params=network_params,
        clients=[
            struct(
                hostname=params.batcher_params.service_name,
                private_key=batcher_private_key,
            ),
            struct(
                hostname=params.proposer_params.service_name,
                private_key=proposer_private_key,
            ),
        ]
        + [
            struct(
                hostname=participant_params.cl.service_name,
                private_key=sequencer_private_key,
            )
            for participant_params in params.participants
        ],
        registry=registry,
        log_prefix=network_log_prefix,
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
            participant_params=participant_params,
            network_params=network_params,
            supervisors_params=supervisors_params,
            is_sequencer=is_sequencer,
            da_params=params.da_params,
            el_context=el.context,
            cl_contexts=cl_contexts,
            signer_context=signer,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts + [el.context],
            observability_helper=observability_helper,
            log_prefix=participant_log_prefix,
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
            el_context=el.context,
            cl_contexts=cl_contexts,
            signer_context=signer,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )

        # Add the EL/CL pair to the list of launched participants
        participants.append(
            struct(
                el=el,
                cl=cl,
                name=participant_name,
                sidecar=sidecar_and_builders.sidecar if sidecar_and_builders else None,
            )
        )

    return struct(
        name=network_params.name,
        network_id=network_params.network_id,
        participants=participants,
        da=da,
        signer=signer,
    )


def _launch_da_maybe(plan, da_params, log_prefix):
    if da_params:
        plan.print("{}: Launching DA".format(log_prefix))

        da = _da_server_launcher.launch(
            plan=plan,
            params=da_params,
        )

        plan.print("{}: Successfully launched DA".format(log_prefix))

        return da


def _launch_sidecar_maybe(
    plan,
    participant_params,
    network_params,
    da_params,
    supervisors_params,
    is_sequencer,
    el_context,
    cl_contexts,
    signer_context,
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
    mev_params = participant_params.mev_params
    if not mev_params:
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
        observability_helper=observability_helper,
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
            signer_context=signer_context,
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
    plan,
    mev_params,
    network_params,
    sequencer_context,
    builder_context,
    jwt_file,
    observability_helper,
):
    if mev_params.type == "rollup-boost":
        return _rollup_boost_launcher.launch(
            plan=plan,
            params=mev_params,
            network_params=network_params,
            sequencer_context=sequencer_context,
            builder_context=builder_context,
            jwt_file=jwt_file,
            observability_helper=observability_helper,
        )
    else:
        fail("Invalid MEV type: {}".format(mev_params.type))


def _launch_signer_maybe(
    plan, signer_params, network_params, clients, registry, log_prefix
):
    if signer_params:
        plan.print("{}: Launching signer".format(log_prefix))

        _op_signer_launcher.launch(
            plan=plan,
            params=signer_params,
            network_params=network_params,
            clients=clients,
            registry=registry,
        )

        plan.print("{}: Successfully launched signer".format(log_prefix))
