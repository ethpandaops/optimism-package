_cl_launcher = import_module("./participant/cl/launcher.star")
_el_launcher = import_module("./participant/el/launcher.star")
_da_server_launcher = import_module("/src/da/da-server/launcher.star")
_op_batcher_launcher = import_module("/src/batcher/op-batcher/launcher.star")
_op_proposer_launcher = import_module("/src/proposer/op-proposer/launcher.star")
_proxyd_launcher = import_module("/src/proxyd/launcher.star")
_tx_fuzzer_launcher = import_module("/src/tx-fuzzer/launcher.star")

_selectors = import_module("./selectors.star")


def launch(
    plan,
    params,
    supervisors_params,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
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

    _launch_da_maybe(
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
            # FIXME
            supervisors_params=[],
        )

        #
        # Launch the CL client
        #

        cl_params = participant_params.cl
        cl_contexts = [p.cl.context for p in participants]

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
        participants.append(struct(el=el, cl=cl, name=participant_name))

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


def _launch_da_maybe(plan, da_params, log_prefix):
    if da_params:
        plan.print("{}: Launching DA".format(log_prefix))

        _da_server_launcher.launch(
            plan=plan,
            params=da_params,
        ).context

        plan.print("{}: Successfully launched DA".format(log_prefix))


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


def _launch_tx_fuzzer_maybe(
    plan, tx_fuzzer_params, participants, node_selectors, log_prefix
):
    if tx_fuzzer_params:
        plan.print("{}: Launching tx fuzzer".format(log_prefix))

        _tx_fuzzer_launcher.launch(
            plan=plan,
            params=tx_fuzzer_params,
            # FIXME
            el_context=participants[0].el.context,
            node_selectors=node_selectors,
        )

        plan.print("{}: Successfully launched tx fuzzer".format(log_prefix))
