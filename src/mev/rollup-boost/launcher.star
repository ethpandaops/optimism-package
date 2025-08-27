_el_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_context.star"
)
_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_net = import_module("/src/util/net.star")
_observability = import_module("/src/observability/observability.star")

_DEFAULT_FLASHBLOCKS_WS_PORT = 1111


def launch(
    plan,
    params,
    network_params,
    sequencer_context,
    builder_context,
    jwt_file,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        jwt_file=jwt_file,
        sequencer_context=sequencer_context,
        builder_context=builder_context,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    rpc_port = params.ports[_net.RPC_PORT_NAME]
    ws_port = params.ports[_net.WS_PORT_NAME]

    return struct(
        service=service,
        context=_el_context.new_el_context(
            client_name=params.type,
            enode=None,
            ip_addr=service.ip_address,
            rpc_port_num=rpc_port.number,
            ws_port_num=ws_port.number,
            engine_rpc_port_num=rpc_port.number,
            rpc_http_url=_net.service_url(params.service_name, rpc_port),
            service_name=params.service_name,
        ),
    )


def get_service_config(
    plan,
    params,
    jwt_file,
    sequencer_context,
    builder_context,
    observability_helper,
):
    L2_EXECUTION_ENGINE_ENDPOINT = _net.service_url(
        sequencer_context.service_name,
        _net.port(number=sequencer_context.engine_rpc_port_num),
    )

    BUILDER_EXECUTION_ENGINE_ENDPOINT = _net.service_url(
        builder_context.service_name,
        _net.port(number=builder_context.engine_rpc_port_num),
    )

    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "--l2-jwt-path=" + _constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l2-url={0}".format(L2_EXECUTION_ENGINE_ENDPOINT),
        "--l2-timeout=" + params.l2_timeout,
        "--builder-jwt-path=" + _constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--builder-url={0}".format(BUILDER_EXECUTION_ENGINE_ENDPOINT),
        "--builder-timeout=" + params.builder_timeout,
        "--rpc-host=0.0.0.0",
        "--rpc-port={0}".format(ports[_net.RPC_PORT_NAME].number),
        "--log-level=debug",
        # Flashblocks configuration
        "--flashblocks",
        "--flashblocks-host=0.0.0.0",
        "--flashblocks-port={}".format(ports[_net.WS_PORT_NAME].number),
        "--flashblocks-builder-url={}".format(
            _net.service_url(
                builder_context.service_name,
                _net.port(
                    number=_DEFAULT_FLASHBLOCKS_WS_PORT, application_protocol="ws"
                ),
            )
        ),
        "--log-format=json",
    ]

    env_vars = {
        "DEBUG_HOST": "0.0.0.0",
        "DEBUG_SERVER_PORT": "5555",
    }

    return ServiceConfig(
        image=params.image,
        ports=ports,
        cmd=cmd,
        env_vars=env_vars,
        files={
            _constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        private_ip_address_placeholder=_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        labels=params.labels,
    )
