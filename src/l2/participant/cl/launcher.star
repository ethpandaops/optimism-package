_hildr_launcher = import_module("/src/cl/hildr/launcher.star")
_kona_node_launcher = import_module("/src/cl/kona-node/launcher.star")
_op_node_launcher = import_module("/src/cl/op-node/launcher.star")


def launch(
    plan,
    params,
    network_params,
    supervisors_params,
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
    if params.type == "hildr":
        return _hildr_launcher.launch(
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
        return _kona_node_launcher.launch(
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
        return _op_node_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            da_params=da_params,
            supervisors_params=supervisors_params,
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
