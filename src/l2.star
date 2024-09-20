participant_network = import_module("./participant_network.star")
blockscout = import_module("./blockscout/blockscout_launcher.star")
contract_deployer = import_module("./contracts/contract_deployer.star")
input_parser = import_module("./package_io/input_parser.star")
static_files = import_module(
    "github.com/ethpandaops/ethereum-package/src/static_files/static_files.star"
)


def launch_l2(
    plan,
    l2_services_suffix,
    l2_args,
    deployment_output,
    l1_config,
    l1_priv_key,
    l1_bootnode_context,
):
    network_params = l2_args.network_params

    l2_config_env_vars = {}
    l2_config_env_vars["L2_CHAIN_ID"] = str(network_params.network_id)
    l2_config_env_vars["L2_BLOCK_TIME"] = str(network_params.seconds_per_slot)

    plan.print("Deploying L2 with name {0}".format(network_params.name))
    jwt_file = plan.upload_files(
        src=static_files.JWT_PATH_FILEPATH,
        name="op_jwt_file{0}".format(l2_services_suffix),
    )

    all_l2_participants = participant_network.launch_participant_network(
        plan,
        l2_args.participants,
        jwt_file,
        network_params,
        deployment_output,
        l1_config,
        l2_services_suffix,
    )

    all_el_contexts = []
    all_cl_contexts = []
    for participant in all_l2_participants:
        all_el_contexts.append(participant.el_context)
        all_cl_contexts.append(participant.cl_context)

    # for additional_service in l2_args.additional_services:
    #     if additional_service == "blockscout":
    #         plan.print("Launching op-blockscout")
    #         blockscout_launcher = blockscout.launch_blockscout(
    #             plan,
    #             l2_services_suffix,
    #             l1_bootnode_context,  # first l1 EL url
    #             all_el_contexts[0],  # first l2 EL url
    #             l2oo_address,
    #             network_params.name,
    #             blockscout_env_variables,
    #         )
    #         plan.print("Successfully launched op-blockscout")
    #
    # plan.print(all_l2_participants)
    # plan.print(
    #     "Begin your L2 adventures by depositing some L1 Kurtosis ETH to: {0}".format(
    #         l1_bridge_address
    #     )
    # )


def get_network_fork_activation(network_params):
    env_vars = {}
    env_vars["FJORD_TIME_OFFSET"] = "0x" + "%x" % int(network_params.fjord_time_offset)
    if network_params.granite_time_offset != None:
        env_vars["GRANITE_TIME_OFFSET"] = "0x" + "%x" % int(
            network_params.granite_time_offset
        )
    if network_params.holocene_time_offset != None:
        env_vars["HOLOCENE_TIME_OFFSET"] = "0x" + "%x" % int(
            network_params.holocene_time_offset
        )
    if network_params.interop_time_offset != None:
        env_vars["INTEROP_TIME_OFFSET"] = "0x" + "%x" % int(
            network_params.interop_time_offset
        )
    return env_vars
