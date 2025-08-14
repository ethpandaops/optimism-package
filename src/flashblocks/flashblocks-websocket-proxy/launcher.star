_observability = import_module("/src/observability/observability.star")
_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_net = import_module("/src/util/net.star")


def launch(
    plan,
    params,
    conductors_contexts,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        conductors_contexts=conductors_contexts,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    ws_port = params.ports[_net.WS_PORT_NAME]
    ws_url = "ws://{}:{}".format(service.ip_address, ws_port.number)

    metrics_info = _observability.new_metrics_info(observability_helper, service)

    return struct(
        service=service,
        context=struct(
            service_name=params.service_name,
            service_ip_address=service.ip_address,
            ws_port=ws_port.number,
            ws_url=ws_url,
            metrics_info=[metrics_info],
        ),
    )


def get_service_config(
    plan,
    params,
    conductors_contexts,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    upstream_urls = []
    for conductor_context in conductors_contexts:
        # Use conductor RPC port + /ws; the conductor serves WS on the same port
        ws_url = "ws://{}:{}/ws".format(
            conductor_context.service_name, conductor_context.conductor_rpc_port
        )
        upstream_urls.append(ws_url)

    upstream_ws_str = ",".join(upstream_urls)

    config_map_env = {
        "GLOBAL_CONNECTIONS_LIMIT": "100",
        "IP_ADDR_HTTP_HEADER": "X-Forwarded-For",
        "LISTEN_ADDR": "0.0.0.0:8545",
        "LOG_FORMAT": "text",
        "LOG_LEVEL": "info",
        "MESSAGE_BUFFER_SIZE": "20",
        "METRICS": "true",
        "METRICS_ADDR": "0.0.0.0:9000",
        "PER_IP_CONNECTIONS_LIMIT": "10",
        "UPSTREAM_WS": upstream_ws_str,
    }

    return ServiceConfig(
        image=params.image,
        ports=ports,
        env_vars=config_map_env,
        labels=params.labels,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
