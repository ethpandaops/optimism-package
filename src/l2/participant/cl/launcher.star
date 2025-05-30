_hildr_launcher = import_module("/src/cl/hildr/launcher.star")


def launch(
    plan,
    params,
    network_params,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    bootnode_contexts,
    observability_helper,
):
    if params.type == "hildr":
        return _hildr_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            observability_helper=observability_helper,
        )
