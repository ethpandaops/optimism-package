ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")
contract_deployer = import_module("./src/contracts/contract_deployer.star")
static_files = import_module("github.com/ethpandaops/ethereum-package/src/static_files/static_files.star")
l2_launcher = import_module("./src/l2.star")
input_parser = import_module("./src/package_io/input_parser.star")


def run(plan, args): 
    """Deploy Optimism L2s on an Ethereum L1.

    Args:
        args(json): Configures other aspects of the environment.
    Returns:
        Full Optimism L2s. 
    """
    plan.print("Parsing the L1 input args")
    ethereum_args = args["ethereum_package"]

    # Deploy the L1
    plan.print("Deploying a local L1")
    l1 = ethereum_package.run(plan, ethereum_args)
    
    # Get L1 info
    all_l1_participants = l1.all_participants
    l1_network_params = l1.network_params
    l1_priv_key = l1.pre_funded_accounts[12].private_key  # reserved for L2 contract deployers
    l1_config_env_vars = get_l1_config(all_l1_participants, l1_network_params)

    # Deploy Create2 Factory contract (only need to do this once for multiple l2s)
    l2_private_keys = contract_deployer.deploy_factory_contract(plan, l1_priv_key, l1_config_env_vars)

    # Deploy L2s
    if type(args["optimism_package"]) == "dict":
        l2_services_suffix = "" # no suffix if one l2
        l2_launcher.launch_l2(plan, l2_services_suffix, args["optimism_package"], l1_config_env_vars, l1_priv_key, all_l1_participants[0].el_context, l2_private_keys)
    elif type(args["optimism_package"]) == "list":
        for l2_num, l2_args in enumerate(args["optimism-package"]):
            l2_services_suffix = "-{0}".format(l2_args["network_params"]["name"]) # suffix with rollup name, and enforce a name is provided to distinguish them
            l2_launcher.launch_l2(plan, l2_num, l2_services_suffix, l1_config_env_vars, l1_priv_key, all_l1_participants[0].el_context, l2_private_keys)
    else:
        fail("invalid type provided for param: `optimism-package`")


def get_l1_config(all_l1_participants, l1_network_params):
    env_vars = {}
    env_vars["L1_RPC_KIND"] = "any"
    env_vars["WEB3_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["L1_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["CL_RPC_URL"] = str(all_l1_participants[0].cl_context.beacon_http_url)
    env_vars["L1_CHAIN_ID"] = str(l1_network_params.network_id)
    env_vars["L1_BLOCK_TIME"] = str(l1_network_params.seconds_per_slot)
    env_vars["DEPLOYMENT_OUTFILE"] = (
        "/workspace/optimism/packages/contracts-bedrock/deployments/"
        + str(l1_network_params.network_id)
        + "/kurtosis.json"
    )
    env_vars["STATE_DUMP_PATH"] = (
        "/workspace/optimism/packages/contracts-bedrock/deployments/"
        + str(l1_network_params.network_id)
        + "/state-dump.json"
    )

    return env_vars


