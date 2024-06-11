ethereum_package = import_module("github.com/kurtosis-tech/ethereum-package/main.star")
static_files = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/static_files/static_files.star"
)
l2_launcher = import_module("./src/l2.star")

def run(plan, args={}): 
    """Deploy Optimism L2s on an Ethereum L1.

    Args:
        args(yaml): Configures other aspects of the environment.
    Returns:
        Full Optimism L2s. 
    """
    plan.print("Parsing the L1 input args")
    ethereum_args = args["l1"]

    # Deploy the L1
    plan.print("Deploying a local L1")
    l1 = ethereum_package.run(plan, ethereum_args)
    
    # Get L1 info
    all_l1_participants = l1.all_participants
    l1_network_params = l1.network_params
    l2_num = 0
    num_l2s = len(args["l2s"])
    l1_priv_keys = []
    for i in range(0, num_l2s):
        if 12 + l2_num > len(l1.pre_funded_accounts) - 1:
            fail("cannot support this many l2s yet")
        l1_priv_key = l1.pre_funded_accounts[12 + l2_num].private_key  # reserved for L2 contract deployers
        l1_priv_keys.append(l1_priv_key)
        l2_num += 1
    plan.print("l1 private keys for contract deployers {0}".format(l1_priv_keys))

    # l1_config_env_vars = get_l1_config(all_l1_participants, l1_network_params)

    # Deploy L2s
    for l2_num, l2_args in enumerate(args["l2s"]):
        plan.print("deploying l2 with name {0} and l1 private key {1}".format(l2_args["name"], l1_priv_keys[12 + l2_num]))
        l2_launcher.launch_l2(plan, l2_args, l1_config_env_vars, l1_priv_key[12 + l2_num], all_l1_participants[0].el_context)

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


