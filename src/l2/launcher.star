_cl_launcher = import_module("/src/cl/launcher.star")
_el_launcher = import_module("/src/el/launcher.star")
_da_server_launcher = import_module("/src/da/da-server/launcher.star")
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
            el_context=sidecar_and_builders.el.context
            if sidecar_and_builders and sidecar_and_builders.el
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

        # Add the EL/CL pair to the list of launched participants
        participants.append(
            struct(
                name=participant_name,
                el=el,
                cl=cl,
                el_builder=sidecar_and_builders.el,
                cl_builder=sidecar_and_builders.cl,
                sidecar=sidecar_and_builders.sidecar,
            ) if sidecar_and_builders else struct(
                name=participant_name,
                el=el,
                cl=cl,
                el_builder=None
                cl_builder=None
                sidecar=None,
            )
        )

    return struct(
        name=network_params.name,
        network_id=network_params.network_id,
        participants=participants,
        da=da,
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

    external_el_builder_params = mev_params.external_el_builder
    if external_el_builder_params:
        plan.print(
            "{}: External EL builder specified - EL/CL builders will not be launched".format(
                log_prefix
            )
        )

    el_builder = (
        None
        if external_el_builder_params
        else _el_launcher.launch(
            plan=plan,
            params=mev_params.el_builder,
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
            ip_addr=external_el_builder_params.host,
            engine_rpc_port_num=external_el_builder_params.port,
            rpc_port_num=external_el_builder_params.port,
            rpc_http_url=_net.service_url(
                external_el_builder_params.host, _net.port(number=external_el_builder_params.port)
            ),
            client_name="external-builder",
        )
        if external_el_builder_params
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
        if external_el_builder_params
        else _cl_launcher.launch(
            plan=plan,
            params=mev_params.cl_builder,
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
        el=el_builder,
        cl=cl_builder,
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
