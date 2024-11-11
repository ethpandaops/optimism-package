participant_network = import_module("./participant_network.star")
blockscout = import_module("./blockscout/blockscout_launcher.star")
da_server_launcher = import_module("./alt-da/da-server/da_server_launcher.star")
contract_deployer = import_module("./contracts/contract_deployer.star")
input_parser = import_module("./package_io/input_parser.star")
ethereum_package_static_files = import_module(
    "github.com/ethpandaops/ethereum-package/src/static_files/static_files.star"
)
util = import_module("./util.star")


def launch_l2(
    plan,
    l2_services_suffix,
    l2_args,
    deployment_output,
    l1_config,
    l1_priv_key,
    l1_bootnode_context,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
):
    network_params = l2_args.network_params
    batcher_params = l2_args.batcher_params

    plan.print("Deploying L2 with name {0}".format(network_params.name))
    jwt_file = plan.upload_files(
        src=ethereum_package_static_files.JWT_PATH_FILEPATH,
        name="op_jwt_file{0}".format(l2_services_suffix),
    )

    # we need to launch da-server before launching the participant network
    # because op-node and op-batcher need to know the da-server url, if present
    da_server_context = da_server_launcher.disabled_da_server_context()
    if "da_server" in l2_args.additional_services:
        da_server_image = l2_args.da_server_params.image
        if l2_args.da_server_params.build_image:
            plan.print("Building da-server image")
            da_server_image = ImageBuildSpec(
                image_name=l2_args.da_server_params.image,
                # TODO: this doesn't work... because can't point to a dir outside of the kurtosis package
                # also can't install optimism monorepo as a submodule because that makes the kurtosis package > 100MB, which is not allowed.
                # Not sure how to fix this... detailed problem in https://github.com/ethpandaops/optimism-package/issues/72
                build_context_dir="/optimism/ops/docker/op-stack-go",
                target_stage="da-server-target",
            )
            plan.print("Successfully built da-server image")
        plan.print("Launching da-server")
        da_server_context = da_server_launcher.launch(
            plan,
            "da-server{0}".format(l2_services_suffix),
            da_server_image,
            l2_args.da_server_params.da_server_extra_args,
            l2_args.da_server_params.generic_commitment,
        )
        plan.print("Successfully launched da-server")

    all_l2_participants = participant_network.launch_participant_network(
        plan,
        l2_args.participants,
        jwt_file,
        network_params,
        batcher_params,
        deployment_output,
        l1_config,
        l2_services_suffix,
        global_log_level,
        global_node_selectors,
        global_tolerations,
        persistent,
        da_server_context,
    )

    all_el_contexts = []
    all_cl_contexts = []
    for participant in all_l2_participants:
        all_el_contexts.append(participant.el_context)
        all_cl_contexts.append(participant.cl_context)

    network_id_as_hex = util.to_hex_chain_id(network_params.network_id)
    l1_bridge_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .l1StandardBridgeProxyAddress'.format(
            network_id_as_hex
        ),
    )

    for additional_service in l2_args.additional_services:
        if additional_service == "blockscout":
            plan.print("Launching op-blockscout")
            blockscout.launch_blockscout(
                plan,
                l2_services_suffix,
                l1_bootnode_context,  # first l1 EL url
                all_el_contexts[0],  # first l2 EL url
                network_params.name,
                deployment_output,
                network_params.network_id,
            )
            plan.print("Successfully launched op-blockscout")

    plan.print(all_l2_participants)
    plan.print(
        "Begin your L2 adventures by depositing some L1 Kurtosis ETH to: {0}".format(
            l1_bridge_address
        )
    )
