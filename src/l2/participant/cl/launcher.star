_hildr_launcher = import_module("/src/cl/hildr/launcher.star")


def launch(
    plan,
    params,
    network_params,
    jwt_file,
    deployment_output,
    l1_config_env_vars,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    observability_helper,
):
    if params.type == "hildr":
        return _hildr_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            l1_config_env_vars=l1_config_env_vars,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )
