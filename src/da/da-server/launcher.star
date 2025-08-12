_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
_net = import_module("/src/util/net.star")


def launch(
    plan,
    params,
):
    config = get_service_config(
        plan=plan,
        params=params,
    )

    service = plan.add_service(params.service_name, config)

    return struct(
        service=service,
        # FIXME This can be removed, just requires a little refactoring of the da_server_context variable
        context=struct(
            http_url=_net.service_url(
                service.ip_address, params.ports[_net.HTTP_PORT_NAME]
            )
        ),
    )


def get_service_config(
    plan,
    params,
):
    ports = _net.ports_to_port_specs(params.ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        cmd=params.cmd,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        labels=params.labels,
    )
