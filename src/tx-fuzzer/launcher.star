_constants = import_module("../package_io/constants.star")
_net = import_module("/src/util/net.star")


def launch(
    plan,
    params,
    el_context,
    node_selectors,
):
    config = get_service_config(
        el_context=el_context,
        params=params,
        node_selectors=node_selectors,
    )

    service = plan.add_service(params.service_name, config)

    return struct(service=service)


def get_service_config(
    el_context,
    params,
    node_selectors,
):
    cmd = [
        "spam",
        "--rpc={}".format(
            _net.service_url(
                el_context.service_name, _net.port(number=el_context.rpc_port_num)
            )
        ),
        # FIXME Should not be hardcoded
        "--sk={0}".format(_constants.dev_accounts[0]["private_key"]),
    ] + params.extra_params

    return ServiceConfig(
        image=params.image,
        cmd=cmd,
        min_cpu=params.min_cpu,
        max_cpu=params.max_cpu,
        min_memory=params.min_memory,
        max_memory=params.max_memory,
        node_selectors=node_selectors,
        labels=params.labels,
    )
