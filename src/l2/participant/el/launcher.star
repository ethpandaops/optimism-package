_observability = import_module("/src/observability/observability.star")
_op_geth_launcher = import_module("/src/el/op-geth/launcher.star")

_filter = import_module("/src/util/filter.star")


def launch(
    plan,
    params,
    network_params,
    sequencer_params,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    bootnode_contexts,
    observability_helper,
    supervisors_params,
):
    el = None

    if params.type == "op-geth":
        el = _op_geth_launcher.launch(
            plan=plan,
            params=params,
            network_params=network_params,
            sequencer_params=sequencer_params,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            log_level=log_level,
            persistent=persistent,
            tolerations=tolerations,
            node_selectors=node_selectors,
            bootnode_contexts=bootnode_contexts,
            observability_helper=observability_helper,
            supervisors_params=supervisors_params,
        )
    else:
        # This should never happen since we asserted that the type is valid in the input parser
        # but in untyped/imperfectly typed languages we are doomed to repreat ourselves
        # or resort to implicit knowledge
        fail("Unknown EL type: {}".format(params.type))

    # Register metrics
    for metrics_info in _filter.remove_none(el.context.el_metrics_info):
        _observability.register_node_metrics_job(
            observability_helper,
            params.type,
            "execution",
            network_params.network,
            metrics_info,
        )

    return el
