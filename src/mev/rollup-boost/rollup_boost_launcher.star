imports = import_module("/imports.star")

shared_utils = imports.load_module(
    "src/shared_utils/shared_utils.star",
    package_id="ethereum-package"
)
el_context = imports.load_module(
    "src/el/el_context.star",
    package_id="ethereum-package"
)
el_admin_node_info = imports.load_module(
    "src/el/el_admin_node_info.star",
    package_id="ethereum-package"
)
constants = imports.load_module(
    "src/package_io/constants.star",
    package_id="ethereum-package"
)

RPC_PORT_NUM = 8541
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
RPC_PORT_ID = "rpc"
DEFAULT_IMAGE = "flashbots/rollup-boost:latest"


def get_used_ports(discovery_port=DISCOVERY_PORT_NUM):
    used_ports = {
        RPC_PORT_ID: shared_utils.new_port_spec(
            RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch(
    plan,
    launcher,
    service_name,
    image,
    existing_el_clients,
    sequencer_context,
    builder_context,
):
    network_name = shared_utils.get_network_name(launcher.network)

    config = get_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        launcher.network_id,
        image,
        service_name,
        existing_el_clients,
        sequencer_context,
        builder_context,
    )

    service = plan.add_service(service_name, config)

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)

    return el_context.new_el_context(
        client_name="rollup-boost",
        enode=None,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=RPC_PORT_NUM,
        rpc_http_url=http_url,
        service_name=service_name,
    )


def get_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    network,
    network_id,
    image,
    service_name,
    existing_el_clients,
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

    used_ports = get_used_ports(DISCOVERY_PORT_NUM)

    public_ports = {}
    cmd = [
        "--l2-jwt-path=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l2-url={0}".format(L2_EXECUTION_ENGINE_ENDPOINT),
        "--builder-jwt-path=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--builder-url={0}".format(BUILDER_EXECUTION_ENGINE_ENDPOINT),
        "--rpc-port={0}".format(RPC_PORT_NUM),
        "--log-level=debug",
    ]

    files = {
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    return ServiceConfig(
        image=image,
        ports=used_ports,
        public_ports=public_ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
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
