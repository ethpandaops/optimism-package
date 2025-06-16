participant_network__hack = import_module("./participant_network__hack.star")
_da_server_launcher = import_module("./da/da-server/launcher.star")
_tx_fuzzer_launcher = import_module("./tx-fuzzer/launcher.star")
contract_deployer = import_module("./contracts/contract_deployer.star")
input_parser = import_module("./package_io/input_parser.star")
util = import_module("./util.star")


def launch_l2__hack(
    original_l2_output__hack,
    plan,
    l2_services_suffix,
    l2_args,
    jwt_file,
    deployment_output,
    l1_config,
    l1_priv_key,
    l1_rpc_url,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    observability_helper,
    supervisors_params,
    registry=None,
):
    network_params = l2_args.network_params
    proxyd_params = l2_args.proxyd_params
    batcher_params = l2_args.batcher_params
    proposer_params = l2_args.proposer_params
    mev_params = l2_args.mev_params
    conductor_params = l2_args.conductor_params
    tx_fuzzer_params = l2_args.tx_fuzzer_params

    plan.print("Deploying L2 with name {0}, part 2".format(network_params.name))

    participant_network__hack.launch_participant_network__hack(
        original_participant_network_output__hack=original_l2_output__hack,
        plan=plan,
        participants=l2_args.participants,
        jwt_file=jwt_file,
        network_params=network_params,
        proxyd_params=proxyd_params,
        batcher_params=batcher_params,
        proposer_params=proposer_params,
        mev_params=mev_params,
        conductor_params=conductor_params,
        deployment_output=deployment_output,
        l1_config_env_vars=l1_config,
        l2_services_suffix=l2_services_suffix,
        global_log_level=global_log_level,
        global_node_selectors=global_node_selectors,
        global_tolerations=global_tolerations,
        persistent=persistent,
        observability_helper=observability_helper,
        supervisors_params=supervisors_params,
        da_server_context=original_l2_output__hack.da_server_context__hack,
        registry=registry,
    )
