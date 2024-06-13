participant_network = import_module("./participant_network.star")
blockscout = import_module("./blockscout/blockscout_launcher.star")
contract_deployer = import_module("./contracts/contract_deployer.star")
input_parser = import_module("./package_io/input_parser.star")
static_files = import_module(
    "github.com/ethpandaops/ethereum-package/src/static_files/static_files.star"
)

def launch_l2(plan, l2_args, l1_config, l1_priv_key, l1_bootnode_context):
    # Deploy L2 smart contracts
    # Parse the values for the args
    plan.print("Parsing the L2 input args")
    args_with_right_defaults = input_parser.input_parser(plan, l2_args)
    network_params = args_with_right_defaults.network_params
    l2_config_env_vars = {}
    l2_config_env_vars["L2_CHAIN_ID"] = str(network_params.network_id)
    l2_config_env_vars["L2_BLOCK_TIME"] = str(network_params.seconds_per_slot)

    (
        el_cl_data,
        gs_private_keys,
        l2oo_address,
        l1_bridge_address,
        blockscout_env_variables,
    ) = contract_deployer.deploy_l2_contracts(
        plan,
        l1_priv_key, # get private key of contract deployer for this l2
        l1_config,
        l2_config_env_vars,
    )

    # Deploy the L2
    plan.print("Deploying a local L2")
    jwt_file = plan.upload_files(
        src=static_files.JWT_PATH_FILEPATH,
        name="op_jwt_file-{0}".format(network_params.network_id),
    )

    all_l2_participants = participant_network.launch_participant_network(
        plan,
        args_with_right_defaults.participants,
        jwt_file,
        network_params,
        el_cl_data,
        gs_private_keys,
        l1_config,
        l2oo_address,
    )

    all_el_contexts = []
    all_cl_contexts = []
    for participant in all_l2_participants:
        all_el_contexts.append(participant.el_context)
        all_cl_contexts.append(participant.cl_context)

    for additional_service in args_with_right_defaults.additional_services:
        if additional_service == "blockscout":
            plan.print("Launching op-blockscout")
            blockscout_launcher = blockscout.launch_blockscout(
                plan,
                network_params.network_id,
                l1_bootnode_context, # first l1 EL url
                l2oo_address,
                blockscout_env_variables,
            )
            plan.print("Successfully launched op-blockscout")

    plan.print(all_l2_participants)
    plan.print(
        "Begin your L2 adventures by depositing some L1 Kurtosis ETH to: {0}".format(
            l1_bridge_address
        )
    )
