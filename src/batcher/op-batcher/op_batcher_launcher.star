shared_utils = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star"
)

constants = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/package_io/constants.star"
)


#
#  ---------------------------------- Batcher client -------------------------------------
# The Docker container runs as the "op-batcher" user so we can't write to root
BATCHER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-batcher/op-batcher-beacon-data"

# Port IDs
BEACON_HTTP_PORT_ID = "http"

# Port nums
BEACON_HTTP_PORT_NUM = 8548


def get_used_ports(discovery_port):
    used_ports = {
        BEACON_HTTP_PORT_ID: shared_utils.new_port_spec(
            BEACON_HTTP_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    constants.GLOBAL_LOG_LEVEL.info: "INFO",
    constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}


def launch(
    plan,
    launcher,
    service_name,
    image,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    gs_batcher_private_key,
):
    beacon_service_name = "{0}".format(service_name)

    network_name = shared_utils.get_network_name(launcher.network)
    config = get_beacon_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        image,
        service_name,
        el_context,
        existing_cl_clients,
        l1_config_env_vars,
        gs_batcher_private_key,
    )

    beacon_service = plan.add_service(service_name, config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    return "op_batcher"


def get_beacon_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    image,
    service_name,
    el_context,
    cl_context,
    l1_config_env_vars,
    gs_batcher_private_key,
):
    discovery_port = BEACON_DISCOVERY_PORT_NUM
    used_ports = get_used_ports(discovery_port)

    cmd = [
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--poll-interval=1s",
        "--sub-safety-margin=6",
        "--num-confirmations=1",
        "--safe-abort-nonce-too-low-count=3",
        "--resubmission-timeout=30s",
        "--rpc.addr=0.0.0.0",
        "--rpc.port=" + BEACON_HTTP_PORT_NUM,
        "--rpc.enable-admin",
        "--max-channel-duration=1",
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--private-key=" + gs_batcher_private_key,
    ]

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }
    ports = {}
    ports.update(used_ports)

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ready_conditions=cl_node_ready_conditions.get_ready_conditions(
            BEACON_HTTP_PORT_ID
        ),
    )


def new_op_node_launcher(el_cl_genesis_data, jwt_file, network_params):
    return struct(
        el_cl_genesis_data=el_cl_genesis_data,
        jwt_file=jwt_file,
        network=network_params.network,
    )
