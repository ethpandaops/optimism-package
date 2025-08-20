_blockscout_launcher = import_module("/src/blockscout/launcher.star")
_op_batcher_launcher = import_module("/src/batcher/op-batcher/launcher.star")
_op_conductor_launcher = import_module("/src/conductor/op-conductor/launcher.star")
_op_proposer_launcher = import_module("/src/proposer/op-proposer/launcher.star")
_proxyd_launcher = import_module("/src/proxyd/launcher.star")
_op_signer_launcher = import_module("/src/signer/op-signer/launcher.star")
_tx_fuzzer_launcher = import_module("/src/tx-fuzzer/launcher.star")
_op_conductor_ops_launcher = import_module(
    "/src/conductor/op-conductor-ops/launcher.star"
)

_selectors = import_module("./selectors.star")
_util = import_module("/src/util.star")
_net = import_module("/src/util/net.star")


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

    for index_hack, participant_params in enumerate(params.participants):
        participant_name = participant_params.name
        participant_log_prefix = "{}: Participant {}".format(
            network_log_prefix, participant_name
        )

        plan.print("{}: Launching".format(participant_log_prefix))

        _launch_conductor_maybe(
            plan=plan,
            participant_params=participant_params,
            network_params=network_params,
            supervisors_params=supervisors_params,
            sidecar_context=original_launcher_output__hack.participants[
                index_hack
            ].sidecar.context
            if original_launcher_output__hack.participants[index_hack].sidecar
            else None,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
            log_prefix=participant_log_prefix,
        )

    # We now bootstrap the conductor cluster
    _op_conductor_ops_launcher.launch(
        plan=plan,
        l2_params=params,
        registry=registry,
    )

    # We get a list of sequencers to be used with batcher & proposer
    sequencers_params = _selectors.get_sequencers_params(params.participants)

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

    _launch_signer_maybe(
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
        ],
        registry=registry,
        log_prefix=network_log_prefix,
    )

    _launch_batcher(
        plan=plan,
        batcher_params=params.batcher_params,
        network_params=network_params,
        sequencers_params=sequencers_params,
        private_key=batcher_private_key,
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
        private_key=proposer_private_key,
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


def _launch_signer_maybe(
    plan, signer_params, network_params, clients, registry, log_prefix
):
    if signer_params:
        if len(clients) == 0:
            plan.print(
                "{}: No clients available for signer, skipping launch".format(
                    log_prefix
                )
            )
            return

        plan.print("{}: Launching signer".format(log_prefix))

        _op_signer_launcher.launch(
            plan=plan,
            params=signer_params,
            network_params=network_params,
            clients=clients,
            registry=registry,
        )

        plan.print("{}: Successfully launched signer".format(log_prefix))


def _launch_batcher(
    plan,
    batcher_params,
    sequencers_params,
    network_params,
    private_key,
    l1_config_env_vars,
    observability_helper,
    da_server_context,
    log_prefix,
):
    plan.print("{}: Launching batcher".format(log_prefix))

    return _op_batcher_launcher.launch(
        plan=plan,
        params=batcher_params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=l1_config_env_vars,
        gs_batcher_private_key=private_key,
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
    private_key,
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

    _op_proposer_launcher.launch(
        plan=plan,
        params=proposer_params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=l1_config_env_vars,
        gs_proposer_private_key=private_key,
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
            sidecar_context=sidecar_context,
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
