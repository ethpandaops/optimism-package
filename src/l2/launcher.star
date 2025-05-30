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

    log_prefix = "L2 network {}".format(network_name)

    plan.print(
        "{}: Launching (network ID {})".format(log_prefix, network_params.network_id)
    )

    plan.print("Network params: {}".format(network_params))

    # _launch_da_maybe(plan=plan, da_params=params.da_params)

    #
    # Launch CL & EL clients
    #

    participants = []

    for participant in params.participants:
        plan.print("{}: Launching participant {}".format(log_prefix, participant.name))

        sequencer_params = (
            None
            if _selectors.is_sequencer(participant)
            else _selectors.get_sequencer_params_for(
                participants_params=params.participants, participant_params=participant
            )
        )

        # Launch an EL client
        el = _el_launcher.launch(
            plan=plan,
            params=participant.el,
            network_params=network_params,
            sequencer_params=sequencer_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=[c.el.context for c in participants],
            observability_helper=observability_helper,
            # FIXME
            supervisors_params=[],
        )

        # TODO Launch a CL client

        # Add the pair to the list of launched participants
        # participants.append(struct(el=el, cl=None))

    # _launch_proxyd_maybe(
    #     plan=plan,
    #     proxyd_params=params.proxyd_params,
    #     participants=params.participants,
    #     network_params=network_params,
    #     observability_helper=observability_helper,
    # )
    # _launch_tx_fuzzer_maybe(
    #     plan=plan,
    #     tx_fuzzer_params=params.tx_fuzzer_params,
    #     participants=params.participants,
    #     node_selectors=node_selectors,
    # )


def _launch_da_maybe(plan, da_params):
    if da_params:
        plan.print("Launching DA")

        _da_server_launcher.launch(
            plan=plan,
            params=da_params,
        ).context

        plan.print("Successfully launched DA")


def _launch_proxyd_maybe(
    plan, proxyd_params, participants, network_params, observability_helper
):
    if proxyd_params:
        plan.print("Launching proxyd")

        _proxyd_launcher.launch(
            plan=plan,
            params=proxyd_params,
            network_params=network_params,
            participants=participants,
            observability_helper=observability_helper,
        )

        plan.print("Successfully launched proxyd")


def _launch_tx_fuzzer_maybe(plan, tx_fuzzer_params, participants, node_selectors):
    if tx_fuzzer_params:
        plan.print("Launching tx fuzzer")

        _tx_fuzzer_launcher.launch(
            plan=plan,
            params=tx_fuzzer_params,
            # FIXME
            el_context=participants[0],
            node_selectors=node_selectors,
        )

        plan.print("Successfully launched tx fuzzer")
