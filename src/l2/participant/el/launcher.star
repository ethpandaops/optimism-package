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
    existing_el_clients,
    observability_helper,
    supervisors_params,
):
    service = None

    if params.type == "op-geth":
        return _op_geth_launcher.launch(
            plan=plan,
            params=params,
            participants=participants,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            existing_el_clients=existing_el_clients,
            observability_helper=observability_helper,
            supervisors_params=supervisors_params,
        )
