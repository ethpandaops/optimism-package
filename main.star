ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")
contract_deployer = import_module("./src/contracts/contract_deployer.star")
static_files = import_module(
    "github.com/ethpandaops/ethereum-package/src/static_files/static_files.star"
)
l2_launcher = import_module("./src/l2.star")
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
    ethereum_args = args.get("ethereum_package", input_parser.default_ethereum_config())

    # need to do a raw get here in case only optimism_package is provided.
    # .get will return None if the key is in the config with a None value.
    optimism_args = args.get("optimism_package") or input_parser.default_optimism_args()
    optimism_args_with_right_defaults = input_parser.input_parser(plan, optimism_args)
    # Deploy the L1
    plan.print("Deploying a local L1")
    l1 = ethereum_package.run(plan, ethereum_args)
    plan.print(l1.network_params)
    # Get L1 info
    all_l1_participants = l1.all_participants
    l1_network_params = l1.network_params
    l1_network_id = l1.network_id
    l1_priv_key = l1.pre_funded_accounts[
        12
    ].private_key  # reserved for L2 contract deployers
    l1_config_env_vars = get_l1_config(
        all_l1_participants, l1_network_params, l1_network_id
    )

    if l1_network_params.network == "kurtosis":
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
    )

    for chain in optimism_args_with_right_defaults.chains:
        l2_launcher.launch_l2(
            plan,
            chain.network_params.name,
            chain,
            deployment_output,
            l1_config_env_vars,
            l1_priv_key,
            all_l1_participants[0].el_context,
        )

    return
    # Deploy L2s
    plan.print("Deploying a local L2")
    if type(optimism_args) == "dict":
        l2_services_suffix = ""  # no suffix if one l2
        l2_launcher.launch_l2(
            plan,
            l2_services_suffix,
            optimism_args,
            l1_config_env_vars,
            l1_priv_key,
            all_l1_participants[0].el_context,
        )
    elif type(optimism_args) == "list":
        seen_names = {}
        seen_network_ids = {}
        for l2_num, l2_args in enumerate(optimism_args):
            name = l2_args["network_params"]["name"]
            network_id = l2_args["network_params"]["network_id"]
            if name in seen_names:
                fail(
                    "Duplicate name: {0} provided, make sure you use unique names.".format(
                        name
                    )
                )
            if network_id in seen_network_ids:
                fail(
                    "Duplicate network_id: {0} provided, make sure you use unique network_ids.".format(
                        network_id
                    )
                )

            seen_names[name] = True
            seen_network_ids[network_id] = True
            l2_services_suffix = "-{0}".format(name)
            l2_launcher.launch_l2(
                plan,
                l2_services_suffix,
                l2_args,
                l1_config_env_vars,
                l1_priv_key,
                all_l1_participants[0].el_context,
            )
    else:
        fail("invalid type provided for param: `optimism-package`")


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
