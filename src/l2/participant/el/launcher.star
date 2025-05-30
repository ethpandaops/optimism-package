_op_geth_launcher = import_module("/src/el/op-geth/launcher.star")


def launch(
    plan,
    params,
    participants,
    network_params,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    bootnode_contexts,
    observability_helper,
    supervisors_params,
):
    service = None

    if params.type == "op-geth":
        return _op_geth_launcher.launch(
            plan=plan,
            params=params,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts,
            observability_helper=observability_helper,
            supervisors_params=supervisors_params,
        )
