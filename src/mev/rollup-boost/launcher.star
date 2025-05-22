_el_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_context.star"
)
_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_net = import_module("/src/util/net.star")

# FIXME This don't seem to be passed to the command
WS_PORT_NUM = 8546


def launch(
    plan,
    params,
    network_params,
    sequencer_context,
    builder_context,
    jwt_file,
):
    config = get_service_config(
        plan=plan,
        params=params,
        jwt_file=jwt_file,
        sequencer_context=sequencer_context,
        builder_context=builder_context,
    )

    service = plan.add_service(params.service_name, config)

    return struct(service=service)


def get_service_config(
    plan,
    params,
    jwt_file,
    sequencer_context,
    builder_context,
):
    L2_EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
        sequencer_context.ip_addr,
        sequencer_context.engine_rpc_port_num,
    )

    BUILDER_EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
        builder_context.ip_addr,
        builder_context.engine_rpc_port_num,
    )

    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "--l2-jwt-path=" + _constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l2-url={0}".format(L2_EXECUTION_ENGINE_ENDPOINT),
        "--builder-jwt-path=" + _constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--builder-url={0}".format(BUILDER_EXECUTION_ENGINE_ENDPOINT),
        "--rpc-host=0.0.0.0",
        "--rpc-port={0}".format(RPC_PORT_NUM),
        "--log-level=debug",
    ]

    return ServiceConfig(
        image=params.image,
        ports=ports,
        cmd=cmd,
        files={
            _constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        private_ip_address_placeholder=_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
