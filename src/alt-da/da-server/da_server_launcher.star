_imports = import_module("/imports.star")

_shared_utils = _imports.ext.ethereum_package_shared_utils
_constants = _imports.ext.ethereum_package_constants

# Port IDs
DA_SERVER_HTTP_PORT_ID = "http"

# Port nums
DA_SERVER_HTTP_PORT_NUM = 3100


def get_used_ports():
    used_ports = {
        DA_SERVER_HTTP_PORT_ID: _shared_utils.new_port_spec(
            DA_SERVER_HTTP_PORT_NUM,
            _shared_utils.TCP_PROTOCOL,
            _shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch_da_server(
    plan,
    service_name,
    image,
    cmd,
):
    config = _get_da_server_config(
        image,
        cmd,
    )

    da_server_service = plan.add_service(service_name, config)

    http_url = "http://{0}:{1}".format(
        da_server_service.ip_address, DA_SERVER_HTTP_PORT_NUM
    )
    # da_server_context is passed as argument to op-batcher and op-node(s)
    return new_da_server_context(
        http_url=http_url,
    )


def _get_da_server_config(
    image,
    cmd,
):
    ports = get_used_ports()

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )


def disabled_da_server_context():
    return new_da_server_context(
        http_url="",
    )


def new_da_server_context(http_url):
    return struct(
        enabled=http_url != "",
        http_url=http_url,
    )
