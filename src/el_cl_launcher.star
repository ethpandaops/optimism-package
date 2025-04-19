ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

input_parser = import_module("./package_io/input_parser.star")

observability = import_module("./observability/observability.star")
constants = import_module("./package_io/constants.star")

# EL
op_geth = import_module("./el/op-geth/op_geth_launcher.star")
op_reth = import_module("./el/op-reth/op_reth_launcher.star")
op_erigon = import_module("./el/op-erigon/op_erigon_launcher.star")
op_nethermind = import_module("./el/op-nethermind/op_nethermind_launcher.star")
op_besu = import_module("./el/op-besu/op_besu_launcher.star")
# CL
op_node = import_module("./cl/op-node/op_node_launcher.star")
hildr = import_module("./cl/hildr/hildr_launcher.star")

# MEV
rollup_boost = import_module("./mev/rollup-boost/rollup_boost_launcher.star")
op_geth_builder = import_module("./builder/op-geth/op_geth_launcher.star")
op_reth_builder = import_module("./builder/op-reth/op_reth_launcher.star")
op_rbuilder_builder = import_module("./builder/op-rbuilder/op_rbuilder_launcher.star")
op_node_builder = import_module("./cl/op-node/op_node_builder_launcher.star")

# Conductor
op_conductor = import_module("./op-conductor/op_conductor_launcher.star")


# TODO: Make op_conductor_enabled a configuration on network_params
def launch(
    plan,
    network_params,
    mev_params,
    interop_params,
    jwt_file,
    deployment_output,
    participants,
    l1_config_env_vars,
    l2_services_suffix,
    da_server_context,
    additional_services,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    observability_helper,
):
    el_launchers = {
        "op-geth": {
            "launcher": op_geth.new_op_geth_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_geth.launch,
        },
        "op-reth": {
            "launcher": op_reth.new_op_reth_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_reth.launch,
        },
        "op-erigon": {
            "launcher": op_erigon.new_op_erigon_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_erigon.launch,
        },
        "op-nethermind": {
            "launcher": op_nethermind.new_nethermind_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_nethermind.launch,
        },
        "op-besu": {
            "launcher": op_besu.new_op_besu_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_besu.launch,
        },
    }

    el_builder_launchers = {
        "op-geth": {
            "launcher": op_geth_builder.new_op_geth_builder_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_geth_builder.launch,
        },
        "op-reth": {
            "launcher": op_reth_builder.new_op_reth_builder_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_reth_builder.launch,
        },
        "op-rbuilder": {
            "launcher": op_rbuilder_builder.new_op_rbuilder_builder_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_rbuilder_builder.launch,
        },
    }

    cl_launchers = {
        "op-node": {
            "launcher": op_node.new_op_node_launcher(
                deployment_output, jwt_file, network_params
            ),
            "launch_method": op_node.launch,
        },
        "hildr": {
            "launcher": hildr.new_hildr_launcher(
                deployment_output, jwt_file, network_params
            ),
            "launch_method": hildr.launch,
        },
    }

    cl_builder_launchers = {
        "op-node": {
            "launcher": op_node_builder.new_op_node_builder_launcher(
                deployment_output, jwt_file, network_params
            ),
            "launch_method": op_node_builder.launch,
        },
    }

    op_conductor_launcher = {
        "op-conductor": {
            "launch_method": op_conductor.launch,
            "service_config_method": op_conductor.get_config,
        }
    }

    sidecar_launchers = {
        "rollup-boost": {
            "launcher": rollup_boost.new_rollup_boost_launcher(
                deployment_output,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": rollup_boost.launch,
        }
    }

    all_cl_contexts = []
    all_el_contexts = []

    sequencer_enabled = True
    sequencer_context = None
    rollup_boost_enabled = "rollup-boost" in additional_services

    conductor_enabled = True  # TODO: Dynamically set from input args
    conductor_bootstrapped = False
    conductor_contexts = []
    for index, participant in enumerate(participants):
        if conductor_enabled and sequencer_enabled:
            # Bootstrap the conductor server
            conductor_service_config = op_conductor_launcher["op-conductor"][
                "service_config_method"
            ](
                plan,
                observability_helper,
                deployment_output,
                network_params,
                "true",  # conductor_bootstrapped
                "true",  # paused
            )

            el_context, cl_context_0, sidecar_context = launch_participant(
                plan,
                network_params,
                mev_params,
                interop_params,
                jwt_file,
                deployment_output,
                participant,
                l1_config_env_vars,
                l2_services_suffix,
                da_server_context,
                additional_services,
                global_log_level,
                global_node_selectors,
                global_tolerations,
                persistent,
                observability_helper,
                sequencer_enabled,
                rollup_boost_enabled,
                el_launchers,
                el_builder_launchers,
                cl_launchers,
                cl_builder_launchers,
                sidecar_launchers,
                conductor_enabled,
                index,
                len(str(len(participants))),
                all_cl_contexts,
                all_el_contexts,
                sequencer_context,
                conductor_service_config,
            )

            conductor_context_bootstrap = op_conductor_launcher["op-conductor"][
                "launch_method"
            ](
                plan,
                cl_context_0,
                sidecar_context if sidecar_context != None else el_context,
                observability_helper,
                deployment_output,
                network_params,
                "0",
                conductor_service_config,
            )

            conductor_contexts.append(conductor_context_bootstrap)

            conductor_service_config = op_conductor_launcher["op-conductor"][
                "service_config_method"
            ](
                plan,
                observability_helper,
                deployment_output,
                network_params,
                "false",  # conductor_bootstrapped
                "true",  # paused
            )

            # Launch op-node (maybe rollup-boost) and el
            el_context, cl_context_1, sidecar_context = launch_participant(
                plan,
                network_params,
                mev_params,
                interop_params,
                jwt_file,
                deployment_output,
                participant,
                l1_config_env_vars,
                l2_services_suffix,
                da_server_context,
                additional_services,
                global_log_level,
                global_node_selectors,
                global_tolerations,
                persistent,
                observability_helper,
                sequencer_enabled,
                rollup_boost_enabled,
                el_launchers,
                el_builder_launchers,
                cl_launchers,
                cl_builder_launchers,
                sidecar_launchers,
                conductor_enabled,
                index,
                len(str(len(participants))) + 1,
                all_cl_contexts,
                all_el_contexts,
                sequencer_context,
                conductor_service_config,
            )

            conductor_context_1 = op_conductor_launcher["op-conductor"][
                "launch_method"
            ](
                plan,
                cl_context_1,
                sidecar_context if sidecar_context != None else el_context,
                observability_helper,
                deployment_output,
                network_params,
                "1",
                conductor_service_config,
            )

            conductor_contexts.append(conductor_context_1)

            conductor_service_config = op_conductor_launcher["op-conductor"][
                "service_config_method"
            ](
                plan,
                observability_helper,
                deployment_output,
                network_params,
                "false",  # conductor_bootstrapped
                "true",  # paused
            )

            # Launch op-node (maybe rollup-boost) and el
            el_context, cl_context_2, sidecar_context = launch_participant(
                plan,
                network_params,
                mev_params,
                interop_params,
                jwt_file,
                deployment_output,
                participant,
                l1_config_env_vars,
                l2_services_suffix,
                da_server_context,
                additional_services,
                global_log_level,
                global_node_selectors,
                global_tolerations,
                persistent,
                observability_helper,
                sequencer_enabled,
                rollup_boost_enabled,
                el_launchers,
                el_builder_launchers,
                cl_launchers,
                cl_builder_launchers,
                sidecar_launchers,
                conductor_enabled,
                index,
                len(str(len(participants))) + 2,
                all_cl_contexts,
                all_el_contexts,
                sequencer_context,
                conductor_service_config,
            )

            conductor_context_2 = op_conductor_launcher["op-conductor"][
                "launch_method"
            ](
                plan,
                cl_context_2,
                sidecar_context if sidecar_context != None else el_context,
                observability_helper,
                deployment_output,
                network_params,
                "2",
                conductor_service_config,
            )

            conductor_contexts.append(conductor_context_2)

            # Add cl_context_1, and cl_context_2 as trusted peers of cl_context_0
            recipe_0 = PostHttpRequestRecipe(
                endpoint="/",
                content_type="application/json",
                body="{"
                + '"jsonrpc":"2.0","method":"opp2p_connectPeer","params":["{0}"],"id":1'.format(
                    cl_context_1.multiaddr
                )
                + "}",
                port_id=constants.HTTP_PORT_ID,
            )

            recipe_1 = PostHttpRequestRecipe(
                endpoint="/",
                content_type="application/json",
                body="{"
                + '"jsonrpc":"2.0","method":"opp2p_connectPeer","params":["{0}"],"id":1'.format(
                    cl_context_2.multiaddr
                )
                + "}",
                port_id=constants.HTTP_PORT_ID,
            )

            plan.request(
                recipe=recipe_0,
                service_name=cl_context_0.beacon_service_name,
                acceptable_codes=[200],
            )

            plan.request(
                recipe=recipe_1,
                service_name=cl_context_0.beacon_service_name,
                acceptable_codes=[200],
            )

            # call conductor_addServerAsVoter for on bootstrap server for both spawned services
            # Set op-node's, as trusted peers of each other
            # TODO:
            # bootstrap other two conductor services
            recipe = PostHttpRequestRecipe(
                endpoint="/",
                content_type="application/json",
                body="{"
                + '"jsonrpc":"2.0","method":"conductor_addServerAsVoter","params":["{0}", "{1}", {2}],"id":1'.format(
                    conductor_context_1.conductor_raft_server_id,
                    conductor_context_1.conductor_consensus_addr,
                    conductor_context_1.conductor_raft_config_version,
                )
                + "}",
                port_id=constants.RPC_PORT_ID,
            )

            plan.request(
                recipe=recipe,
                service_name=conductor_context_bootstrap.service_name,
                acceptable_codes=[200],
            )

            recipe = PostHttpRequestRecipe(
                endpoint="/",
                content_type="application/json",
                body="{"
                + '"jsonrpc":"2.0","method":"conductor_addServerAsVoter","params":["{0}", "{1}", {2}],"id":1'.format(
                    conductor_context_2.conductor_raft_server_id,
                    conductor_context_2.conductor_consensus_addr,
                    conductor_context_2.conductor_raft_config_version,
                )
                + "}",
                port_id=constants.RPC_PORT_ID,
            )

            plan.request(
                recipe=recipe,
                service_name=conductor_context_bootstrap.service_name,
                acceptable_codes=[200],
            )

            # Assert cluster membership of the two spawned op-conductor services
            recipe = PostHttpRequestRecipe(
                endpoint="/",
                content_type="application/json",
                body='{"jsonrpc":"2.0","method":"conductor_clusterMembership","params":[],"id":1}',
                port_id=constants.RPC_PORT_ID,
                extract={
                    "servers": ".result.servers",
                },
            )

            response = plan.request(
                recipe=recipe,
                service_name=conductor_context_bootstrap.service_name,
                acceptable_codes=[200],
            )

            servers = response["extract.servers"]

            plan.print(
                "Successfully bootstrapped cluster membership: {0}".format(servers)
            )

            recipe = PostHttpRequestRecipe(
                endpoint="/",
                content_type="application/json",
                body='{"jsonrpc":"2.0","method":"conductor_resume","params":[],"id":1}',
                port_id=constants.RPC_PORT_ID,
            )

            # Note: Any restarts on the containers will cause the conductor services to be paused
            plan.request(
                recipe=recipe,
                service_name=conductor_context_bootstrap.service_name,
                acceptable_codes=[200],
            )

            plan.request(
                recipe=recipe,
                service_name=conductor_context_1.service_name,
                acceptable_codes=[200],
            )

            plan.request(
                recipe=recipe,
                service_name=conductor_context_2.service_name,
                acceptable_codes=[200],
            )

            # stop the bootstrap server
            plan.stop_service(
                name=conductor_context_bootstrap.service_name,
                description="stopping bootstrap conductor",
            )

            bootstrap_server = plan.get_service(
                name=conductor_context_bootstrap.service_name
            )

            # resume all three conductor services

            # set OP_CONDUCTOR_RAFT_BOOTSTRAP: "false and OP_CONDUCTOR_PAUSED: "false"
            # restart leader server

            # stop the other two conductor services
            # set OP_CONDUCTOR_PAUSED: "false"
            # restart the other two conductor services

            # verify cluster membership of the two spawned op-conductor services with conductor_clusterMembership
            # TODO:
            # restart the bootstrap server with OP_CONDUCTOR_RAFT_BOOTSTRAP: "false" and OP_CONDUCTOR_PAUSED: "false"

        # only the first participant is the sequencer
        if sequencer_enabled:
            sequencer_enabled = False

    plan.print("Successfully added {0} EL/CL participants".format(len(participants)))

    return all_el_contexts, all_cl_contexts, conductor_contexts


def launch_participant(
    plan,
    network_params,
    mev_params,
    interop_params,
    jwt_file,
    deployment_output,
    participant,
    l1_config_env_vars,
    l2_services_suffix,
    da_server_context,
    additional_services,
    global_log_level,
    global_node_selectors,
    global_tolerations,
    persistent,
    observability_helper,
    sequencer_enabled,
    rollup_boost_enabled,
    el_launchers,
    el_builder_launchers,
    cl_launchers,
    cl_builder_launchers,
    sidecar_launchers,
    conductor_enabled,
    index,
    length,
    all_cl_contexts,
    all_el_contexts,
    sequencer_context,
    conductor_service_config=None,
):
    external_builder = mev_params.builder_host != "" and mev_params.builder_port != ""

    cl_type = participant.cl_type
    el_type = participant.el_type
    cl_builder_type = participant.cl_builder_type
    el_builder_type = participant.el_builder_type

    node_selectors = ethereum_package_input_parser.get_client_node_selectors(
        participant.node_selectors,
        global_node_selectors,
    )

    el_tolerations = ethereum_package_input_parser.get_client_tolerations(
        participant.el_tolerations, participant.tolerations, global_tolerations
    )

    cl_tolerations = ethereum_package_input_parser.get_client_tolerations(
        participant.cl_tolerations, participant.tolerations, global_tolerations
    )

    if el_type not in el_launchers:
        fail(
            "Unsupported launcher '{0}', need one of '{1}'".format(
                el_type, ",".join(el_launchers.keys())
            )
        )
    if cl_type not in cl_launchers:
        fail(
            "Unsupported launcher '{0}', need one of '{1}'".format(
                cl_type, ",".join(cl_launchers.keys())
            )
        )

    if el_builder_type not in el_builder_launchers:
        fail(
            "Unsupported launcher '{0}', need one of '{1}'".format(
                el_builder_type, ",".join(el_builder_launchers.keys())
            )
        )

    if cl_builder_type not in cl_builder_launchers:
        fail(
            "Unsupported launcher '{0}', need one of '{1}'".format(
                cl_builder_type, ",".join(cl_builder_launchers.keys())
            )
        )

    el_launcher, el_launch_method = (
        el_launchers[el_type]["launcher"],
        el_launchers[el_type]["launch_method"],
    )

    cl_launcher, cl_launch_method = (
        cl_launchers[cl_type]["launcher"],
        cl_launchers[cl_type]["launch_method"],
    )

    el_builder_launcher, el_builder_launch_method = (
        el_builder_launchers[el_builder_type]["launcher"],
        el_builder_launchers[el_builder_type]["launch_method"],
    )

    cl_builder_launcher, cl_builder_launch_method = (
        cl_builder_launchers[cl_builder_type]["launcher"],
        cl_builder_launchers[cl_builder_type]["launch_method"],
    )

    sidecar_launcher, sidecar_launch_method = (
        sidecar_launchers["rollup-boost"]["launcher"],
        sidecar_launchers["rollup-boost"]["launch_method"],
    )

    # Zero-pad the index using the calculated zfill value
    index_str = ethereum_package_shared_utils.zfill_custom(index + 1, length)

    el_service_name = "op-el-{0}-{1}-{2}-{3}".format(
        index_str, el_type, cl_type, l2_services_suffix
    )
    cl_service_name = "op-cl-{0}-{1}-{2}-{3}".format(
        index_str, cl_type, el_type, l2_services_suffix
    )
    el_builder_service_name = "op-el-builder-{0}-{1}-{2}-{3}".format(
        index_str, el_builder_type, cl_builder_type, l2_services_suffix
    )
    cl_builder_service_name = "op-cl-builder-{0}-{1}-{2}-{3}".format(
        index_str, cl_builder_type, el_builder_type, l2_services_suffix
    )
    sidecar_service_name = "op-rollup-boost-{0}-{1}".format(
        index_str, l2_services_suffix
    )

    el_context = el_launch_method(
        plan,
        el_launcher,
        el_service_name,
        participant,
        global_log_level,
        persistent,
        el_tolerations,
        node_selectors,
        all_el_contexts,
        sequencer_enabled,
        sequencer_context,
        observability_helper,
        interop_params,
    )

    all_el_contexts.append(el_context)

    if sequencer_enabled:
        sequencer_context = el_context

    for metrics_info in [x for x in el_context.el_metrics_info if x != None]:
        observability.register_node_metrics_job(
            observability_helper,
            el_context.client_name,
            "execution",
            network_params.network,
            metrics_info,
        )

    sidecar_context = None

    if rollup_boost_enabled and sequencer_enabled:
        plan.print("Starting rollup boost")

        if external_builder:
            el_builder_context = struct(
                ip_addr=mev_params.builder_host,
                engine_rpc_port_num=mev_params.builder_port,
                rpc_port_num=mev_params.builder_port,
                rpc_http_url="http://{0}:{1}".format(
                    mev_params.builder_host, mev_params.builder_port
                ),
                client_name="external-builder",
            )
        else:
            sequencer_context = all_el_contexts[0] if len(all_el_contexts) > 0 else None
            el_builder_context = el_builder_launch_method(
                plan,
                el_builder_launcher,
                el_builder_service_name,
                participant,
                global_log_level,
                persistent,
                el_tolerations,
                node_selectors,
                all_el_contexts,
                False,  # sequencer_enabled
                sequencer_context,
                observability_helper,
                interop_params,
            )
            for metrics_info in [
                x for x in el_builder_context.el_metrics_info if x != None
            ]:
                observability.register_node_metrics_job(
                    observability_helper,
                    el_builder_context.client_name,
                    "execution-builder",
                    network_params.network,
                    metrics_info,
                )
        rollup_boost_image = (
            mev_params.rollup_boost_image
            if mev_params.rollup_boost_image != ""
            else input_parser.DEFAULT_SIDECAR_IMAGES["rollup-boost"]
        )

        sidecar_context = sidecar_launch_method(
            plan,
            sidecar_launcher,
            sidecar_service_name,
            rollup_boost_image,
            all_el_contexts,
            el_context,
            el_builder_context,
        )

        all_el_contexts.append(el_builder_context)
    else:
        sidecar_context = None

    # If conductor is enabled, launch op-conductor here,
    # then launch op-node with conductor enabled
    cl_context = cl_launch_method(
        plan,
        cl_launcher,
        cl_service_name,
        participant,
        global_log_level,
        persistent,
        cl_tolerations,
        node_selectors,
        sidecar_context if rollup_boost_enabled and sequencer_enabled else el_context,
        all_cl_contexts,
        l1_config_env_vars,
        sequencer_enabled,
        observability_helper,
        interop_params,
        da_server_context,
        conductor_enabled,
        conductor_service_config,
    )

    all_cl_contexts.append(cl_context)

    for metrics_info in [x for x in cl_context.cl_nodes_metrics_info if x != None]:
        observability.register_node_metrics_job(
            observability_helper,
            cl_context.client_name,
            "beacon",
            network_params.network,
            metrics_info,
            {
                "supernode": str(cl_context.supernode),
            },
        )

    # We don't deploy CL for external builder
    if rollup_boost_enabled and sequencer_enabled and not external_builder:
        cl_builder_context = cl_builder_launch_method(
            plan,
            cl_builder_launcher,
            cl_builder_service_name,
            participant,
            global_log_level,
            persistent,
            cl_tolerations,
            node_selectors,
            el_builder_context,
            all_cl_contexts,
            l1_config_env_vars,
            False,
            observability_helper,
            interop_params,
            da_server_context,
        )
        for metrics_info in [
            x for x in cl_builder_context.cl_nodes_metrics_info if x != None
        ]:
            observability.register_node_metrics_job(
                observability_helper,
                cl_builder_context.client_name,
                "beacon-builder",
                network_params.network,
                metrics_info,
                {
                    "supernode": str(cl_builder_context.supernode),
                },
            )
        all_cl_contexts.append(cl_builder_context)

    return el_context, cl_context, sidecar_context
