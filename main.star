ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")
contract_deployer = import_module("./src/contracts/contract_deployer.star")
l2_launcher = import_module("./src/l2.star")
op_supervisor_launcher = import_module("./src/supervisor/op-supervisor/op_supervisor_launcher.star")
wait_for_sync = import_module("./src/wait/wait_for_sync.star")
input_parser = import_module("./src/package_io/input_parser.star")


def run(plan, args):
    """Deploy Optimism L2s on an Ethereum L1.

    Args:
        args(json): Configures other aspects of the environment.
    Returns:
        A full deployment of Optimism L2(s)
    """
    plan.print("Parsing the L1 input args")
    # If no args are provided, use the default values with minimal preset
    ethereum_args = args.get("ethereum_package", {})
    external_l1_args = args.get("external_l1_network_params", {})
    if external_l1_args:
        external_l1_args = input_parser.external_l1_network_params_input_parser(
            plan, external_l1_args
        )
    else:
        if "network_params" not in ethereum_args:
            ethereum_args.update(input_parser.default_ethereum_package_network_params())

    # need to do a raw get here in case only optimism_package is provided.
    # .get will return None if the key is in the config with a None value.
    optimism_args = args.get("optimism_package") or input_parser.default_optimism_args()
    optimism_args_with_right_defaults = input_parser.input_parser(plan, optimism_args)
    global_tolerations = optimism_args_with_right_defaults.global_tolerations
    global_node_selectors = optimism_args_with_right_defaults.global_node_selectors
    global_log_level = optimism_args_with_right_defaults.global_log_level
    persistent = optimism_args_with_right_defaults.persistent

    interop_params = optimism_args_with_right_defaults.interop

    # Deploy the L1
    l1_network = ""
    if external_l1_args:
        plan.print("Using external L1")
        plan.print(external_l1_args)

        l1_rpc_url = external_l1_args.el_rpc_url
        l1_priv_key = external_l1_args.priv_key

        l1_config_env_vars = {
            "L1_RPC_KIND": external_l1_args.rpc_kind,
            "L1_RPC_URL": l1_rpc_url,
            "CL_RPC_URL": external_l1_args.cl_rpc_url,
            "L1_WS_URL": external_l1_args.el_ws_url,
            "L1_CHAIN_ID": external_l1_args.network_id,
        }
    else:
        plan.print("Deploying a local L1")
        l1 = ethereum_package.run(plan, ethereum_args)
        plan.print(l1.network_params)
        # Get L1 info
        all_l1_participants = l1.all_participants
        l1_network = "local"
        l1_network_params = l1.network_params
        l1_network_id = l1.network_id
        l1_rpc_url = all_l1_participants[0].el_context.rpc_http_url
        l1_priv_key = l1.pre_funded_accounts[
            12
        ].private_key  # reserved for L2 contract deployers
        l1_config_env_vars = get_l1_config(
            all_l1_participants, l1_network_params, l1_network_id
        )

    if l1_network == "kurtosis":
        plan.print("Waiting for L1 to start up")
        wait_for_sync.wait_for_startup(plan, l1_config_env_vars)
    else:
        plan.print("Waiting for network to sync")
        wait_for_sync.wait_for_sync(plan, l1_config_env_vars)

    deployment_output = contract_deployer.deploy_contracts(
        plan,
        l1_priv_key,
        l1_config_env_vars,
        optimism_args_with_right_defaults,
        l1_network,
    )

    all_participants = []
    for l2_num, chain in enumerate(optimism_args_with_right_defaults.chains):
        l2_launcher.launch_l2(
            plan,
            l2_num,
            chain.network_params.name,
            chain,
            deployment_output,
            l1_config_env_vars,
            l1_priv_key,
            l1_rpc_url,
            global_log_level,
            global_node_selectors,
            global_tolerations,
            persistent,
            interop_params
        ))
    
    if interop_params.enabled:
        op_supervisor_launcher.launch(
            plan,
            all_participants,
            interop_params.supervisor_params,
        )

def get_l1_config(all_l1_participants, l1_network_params, l1_network_id):
    env_vars = {}
    env_vars["L1_RPC_KIND"] = "standard"
    env_vars["WEB3_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["L1_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["CL_RPC_URL"] = str(all_l1_participants[0].cl_context.beacon_http_url)
    env_vars["L1_WS_URL"] = str(all_l1_participants[0].el_context.ws_url)
    env_vars["L1_CHAIN_ID"] = str(l1_network_id)
    env_vars["L1_BLOCK_TIME"] = str(l1_network_params.seconds_per_slot)
    return env_vars
