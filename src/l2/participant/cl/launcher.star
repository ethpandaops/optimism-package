_observability = import_module("/src/observability/observability.star")
_hildr_launcher = import_module("/src/cl/hildr/launcher.star")
_kona_node_launcher = import_module("/src/cl/kona-node/launcher.star")
_op_node_launcher = import_module("/src/cl/op-node/launcher.star")

_filter = import_module("/src/util/filter.star")


def launch(
    plan,
    params,
    network_params,
    supervisors_params,
    conductor_params,
    da_params,
    is_sequencer,
    jwt_file,
    deployment_output,
    el_context,
    cl_contexts,
    l1_config_env_vars,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    observability_helper,
):
    cl = None

    if params.type == "hildr":
        if conductor_params:
            fail("Node {} on network {}: hildr does not support conductor parameters".format(params.name, network_params.network))

        cl = _hildr_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            is_sequencer=is_sequencer,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            el_context=el_context,
            cl_contexts=cl_contexts,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )
    elif params.type == "kona-node":
        if conductor_params:
            fail("Node {} on network {}: kona-node does not support conductor parameters".format(params.name, network_params.network))

        cl = _kona_node_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            is_sequencer=is_sequencer,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            el_context=el_context,
            cl_contexts=cl_contexts,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )
    elif params.type == "op-node":
        cl = _op_node_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            da_params=da_params,
            supervisors_params=supervisors_params,
            conductor_params=conductor_params,
            is_sequencer=is_sequencer,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            el_context=el_context,
            cl_contexts=cl_contexts,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )

    # Register metrics
    for metrics_info in _filter.remove_none(cl.context.cl_nodes_metrics_info):
        _observability.register_node_metrics_job(
            observability_helper,
            params.type,
            "beacon",
            network_params.network,
            metrics_info,
        )

    return cl
