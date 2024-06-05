shared_utils = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star"
)

cl_context = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/cl/cl_context.star"
)

cl_node_ready_conditions = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/cl/cl_node_ready_conditions.star"
)
constants = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/package_io/constants.star"
)

node_metrics = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/node_metrics_info.star"
)

#  ---------------------------------- Beacon client -------------------------------------

# The Docker container runs as the "op-node" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-node/op-node-beacon-data"
ROLLUP_CONFIG_MOUNT_PATH_ON_CONTAINER = "/network-config/rollup-config.json"
# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"
BEACON_METRICS_PORT_ID = "metrics"
VALIDATOR_HTTP_PORT_ID = "http-validator"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9000
BEACON_HTTP_PORT_NUM = 4000
BEACON_METRICS_PORT_NUM = 8008


BEACON_METRICS_PATH = "/metrics"

MIN_PEERS = 1


def get_used_ports(discovery_port):
    used_ports = {
        BEACON_TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.TCP_PROTOCOL
        ),
        BEACON_UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.UDP_PROTOCOL
        ),
        BEACON_HTTP_PORT_ID: shared_utils.new_port_spec(
            BEACON_HTTP_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        BEACON_METRICS_PORT_ID: shared_utils.new_port_spec(
            BEACON_METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
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
    gs_sequencer_private_key,
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
        gs_sequencer_private_key,
    )

    beacon_service = plan.add_service(service_name, config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    beacon_metrics_port = beacon_service.ports[BEACON_METRICS_PORT_ID]
    beacon_metrics_url = "{0}:{1}".format(
        beacon_service.ip_address, beacon_metrics_port.number
    )

    beacon_node_identity_recipe = GetHttpRequestRecipe(
        endpoint="/eth/v1/node/identity",
        port_id=BEACON_HTTP_PORT_ID,
        extract={
            "enr": ".data.enr",
            "multiaddr": ".data.p2p_addresses[0]",
            "peer_id": ".data.peer_id",
        },
    )
    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=service_name
    )
    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    beacon_node_metrics_info = node_metrics.new_node_metrics_info(
        service_name, BEACON_METRICS_PATH, beacon_metrics_url
    )
    nodes_metrics_info = [beacon_node_metrics_info]

    return cl_context.new_cl_context(
        "op-node",
        beacon_node_enr,
        beacon_service.ip_address,
        beacon_http_port.number,
        beacon_http_url,
        nodes_metrics_info,
        beacon_service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
    )


def get_beacon_config(
    plan,
    el_cl_genesis_data,
    jwt_file,
    image,
    service_name,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    gs_sequencer_private_key,
):
    EXECUTION_ENGINE_ENDPOINT = el_context.rpc_http_url

    discovery_port = BEACON_DISCOVERY_PORT_NUM
    used_ports = get_used_ports(discovery_port)

    cmd = [
        "--l2={0}".format(EXECUTION_ENGINE_ENDPOINT),
        "--l2.jwt-secret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--sequencer.enabled",
        "--sequencer.l1-confs=5",
        "--verifier.l1-confs=4",
        "--rollup.config=" + ROLLUP_CONFIG_MOUNT_PATH_ON_CONTAINER,
        "--rpc.addr=0.0.0.0",
        "--rpc.port={0}".format(BEACON_HTTP_PORT_NUM),
        "--p2p.disable",
        "--rpc.enable-admin",
        "--p2p.sequencer.key=" + gs_sequencer_private_key,
        "--l1=$L1_RPC_URL",
        "--l1.rpckind=$L1_RPC_KIND",
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
        env_vars=l1_config_env_vars,
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
