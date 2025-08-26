_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_net = import_module("/src/util/net.star")
_observability = import_module("/src/observability/observability.star")


def launch(
    plan,
    params,
    conductors_params,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        conductors_params=conductors_params,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    return struct(service=service)


def get_service_config(
    plan,
    params,
    conductors_params,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    upstream_urls = []
    for conductor_params in conductors_params:
        if conductor_params.websocket_enabled:
            # Flashblocks-enabled conductors have a websocket port exposed
            upstream_urls.append(
                _net.service_url(
                    conductor_params.service_name,
                    conductor_params.ports[_net.WS_PORT_NAME],
                )
                + "/ws"
            )

    env_vars = {
        "GLOBAL_CONNECTIONS_LIMIT": str(params.global_connections_limit),
        "LISTEN_ADDR": "0.0.0.0:{}".format(params.ports[_net.WS_PORT_NAME].number),
        "LOG_FORMAT": params.log_format,
        "LOG_LEVEL": params.log_level,
        "MESSAGE_BUFFER_SIZE": str(params.message_buffer_size),
        "PER_IP_CONNECTIONS_LIMIT": str(params.per_ip_connections_limit),
        "UPSTREAM_WS": ",".join(upstream_urls),
    }

    if observability_helper.enabled:
        env_vars |= {
            "METRICS": "true",
            "METRICS_ADDR": "0.0.0.0:{}".format(_observability.METRICS_PORT_NUM),
        }
        _observability.expose_metrics_port(ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        env_vars=env_vars,
        labels=params.labels,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
