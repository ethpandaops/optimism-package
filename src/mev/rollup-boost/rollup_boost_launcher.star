_imports = import_module("/imports.star")

_shared_utils = _imports.ext.ethereum_package_shared_utils
_el_context = _imports.ext.ethereum_package_el_context
_constants = _imports.ext.ethereum_package_constants

RPC_PORT_NUM = 8541
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
RPC_PORT_ID = "rpc"
DEFAULT_IMAGE = "flashbots/rollup-boost:latest"


def _get_used_ports():
    used_ports = {
        RPC_PORT_ID: _shared_utils.new_port_spec(
            RPC_PORT_NUM,
            _shared_utils.TCP_PROTOCOL,
            _shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch(
    plan,
    sidecar_args
):
    config = _get_config(
        jwt_file=sidecar_args.launcher.jwt_file,
        image=sidecar_args.image,
        sequencer_context=sidecar_args.sequencer_context,
        builder_context=sidecar_args.builder_context,
    )

    service = plan.add_service(sidecar_args.service_name, config)

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)

    return _el_context.new_el_context(
        client_name="rollup-boost",
        enode=None,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=RPC_PORT_NUM,
        rpc_http_url=http_url,
        service_name=sidecar_args.service_name,
    )


def _get_config(
    jwt_file,
    image,
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

    used_ports = _get_used_ports()

    public_ports = {}
    cmd = [
        "--l2-jwt-path=" + _constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l2-url={0}".format(L2_EXECUTION_ENGINE_ENDPOINT),
        "--builder-jwt-path=" + _constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--builder-url={0}".format(BUILDER_EXECUTION_ENGINE_ENDPOINT),
        "--rpc-port={0}".format(RPC_PORT_NUM),
        "--log-level=debug",
    ]

    files = {
        _constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    return ServiceConfig(
        image=image,
        ports=used_ports,
        public_ports=public_ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )


def new_rollup_boost_launcher(
    el_cl_genesis_data,
    jwt_file,
    network,
    network_id,
):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network,
        network_id=network_id,
    )
