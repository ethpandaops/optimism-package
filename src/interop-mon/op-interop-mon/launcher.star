"""
Support for the op-interop-mon service.
"""
observability = import_module("../../observability/observability.star")
_net = import_module("/src/util/net.star")


def launch(
    plan,
    image,
    l2s,
    observability_helper,
):
    """Launch the op-interop-mon service.

    Args:
        plan: The plan to add the service to.
        image (str): The image to use for the op-interop-mon service.
        l2_rpcs (str): Comma-separated list of L2 RPC endpoints to monitor.
    """

    cmd = [
        "op-interop-mon",
        "--l2-rpcs={}".format(
            ",".join([p.el.context.rpc_http_url for l2 in l2s for p in l2.participants])
        ),
    ]

    ports = _net.ports_to_port_specs(
        {
            "metrics": _net.port(number=7300),
        }
    )

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    if params.pprof_enabled:
        observability.configure_op_service_pprof(cmd, ports)

    config = ServiceConfig(
        image=image,
        cmd=cmd,
        ports=ports,
    )

    service = plan.add_service("op-interop-mon", config)

    if observability_helper.enabled:
        observability.register_op_service_metrics_job(
            observability_helper,
            service,
        )

    return struct(service=service)
