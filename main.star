input_parser = import_module("./src/package_io/input_parser.star")
ethereum_package = import_module("github.com/kurtosis-tech/ethereum-package/main.star")
contract_deployer = import_module("./src/contracts/contract_deployer.star")
static_files = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/static_files/static_files.star"
)
participant_network = import_module("./src/participant_network.star")


def get_l1_stuff(all_l1_participants, l1_network_params):
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


def run(plan, args={}):
    """Deploy a Optimism L2 with a local L1.

    Args:
        args(yaml): Configures other aspects of the environment.
    Returns:
        A full deployment of Optimism L2
    """

    # Parse the values for the args
    plan.print("Parsing the L1 input args")

    ethereum_args = args["ethereum_package"]

    # Deploy the L1
    plan.print("Deploying a local L1")
    l1 = ethereum_package.run(plan, ethereum_args)
    all_l1_participants = l1.all_participants
    l1_network_params = l1.network_params
    priv_key = l1.pre_funded_accounts[
        12
    ].private_key  # reserved for L2 contract deployer
    # Deploy L2 smart contracts
    # Parse the values for the args
    plan.print("Parsing the L2 input args")
    optimism_args = args["optimism_package"]

    l1_config_env_vars = get_l1_stuff(all_l1_participants, l1_network_params)

    args_with_right_defaults = input_parser.input_parser(plan, optimism_args)
    network_params = args_with_right_defaults.network_params

    l2_config_env_vars = {}
    l2_config_env_vars["L2_CHAIN_ID"] = str(network_params.network_id)
    l2_config_env_vars["L2_BLOCK_TIME"] = str(network_params.seconds_per_slot)

    el_cl_data, gs_sequencer_private_key = contract_deployer.launch_contract_deployer(
        plan,
        priv_key,
        l1_config_env_vars,
        l2_config_env_vars,
    )

    # Deploy the L2
    plan.print("Deploying a local L2")

    jwt_file = plan.upload_files(
        src=static_files.JWT_PATH_FILEPATH,
        name="op_jwt_file",
    )

    all_participants = participant_network.launch_participant_network(
        plan,
        args_with_right_defaults.participants,
        jwt_file,
        network_params,
        el_cl_data,
        gs_sequencer_private_key,
        l1_config_env_vars,
    )

    plan.print(all_participants)
