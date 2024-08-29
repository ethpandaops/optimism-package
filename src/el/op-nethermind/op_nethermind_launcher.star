shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

el_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_context.star"
)
el_admin_node_info = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_admin_node_info.star"
)

node_metrics = import_module(
    "github.com/ethpandaops/ethereum-package/src/node_metrics_info.star"
)
constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551
METRICS_PORT_NUM = 9001

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 300
EXECUTION_MIN_MEMORY = 512

# Port IDs
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"
ENGINE_WS_PORT_ID = "engineWs"
METRICS_PORT_ID = "metrics"

# TODO(old) Scale this dynamically based on CPUs available and Nethermind nodes mining
NUM_MINING_THREADS = 1

METRICS_PATH = "/debug/metrics/prometheus"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/nethermind/execution-data"


def get_used_ports(discovery_port=DISCOVERY_PORT_NUM):
    used_ports = {
        RPC_PORT_ID: shared_utils.new_port_spec(
            RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        WS_PORT_ID: shared_utils.new_port_spec(WS_PORT_NUM, shared_utils.TCP_PROTOCOL),
        TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.TCP_PROTOCOL
        ),
        UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.UDP_PROTOCOL
        ),
        ENGINE_RPC_PORT_ID: shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
        ),
        METRICS_PORT_ID: shared_utils.new_port_spec(
            METRICS_PORT_NUM, shared_utils.TCP_PROTOCOL
        ),
    }
    return used_ports


VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "1",
    constants.GLOBAL_LOG_LEVEL.warn: "2",
    constants.GLOBAL_LOG_LEVEL.info: "3",
    constants.GLOBAL_LOG_LEVEL.debug: "4",
    constants.GLOBAL_LOG_LEVEL.trace: "5",
}


def launch(
    plan,
    launcher,
    service_name,
    image,
    existing_el_clients,
    sequencer_enabled,
    sequencer_context,
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
        sequencer_enabled,
        sequencer_context,
    )

    service = plan.add_service(service_name, config)

    enode = el_admin_node_info.get_enode_for_node(plan, service_name, RPC_PORT_ID)

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    nethermind_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)
    ws_url = "ws://{0}:{1}".format(service.ip_address, WS_PORT_NUM)

    return el_context.new_el_context(
        client_name="op-nethermind",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        ws_url=ws_url,
        service_name=service_name,
        el_metrics_info=[nethermind_metrics_info],
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
    sequencer_enabled,
    sequencer_context,
):
    discovery_port = DISCOVERY_PORT_NUM
    used_ports = get_used_ports(discovery_port)
    cmd = [
        "--log=debug",
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--Init.WebSocketsEnabled=true",
        "--JsonRpc.Enabled=true",
        "--JsonRpc.EnabledModules=net,eth,consensus,subscribe,web3,admin",
        "--JsonRpc.Host=0.0.0.0",
        "--JsonRpc.Port={0}".format(RPC_PORT_NUM),
        "--JsonRpc.WebSocketsPort={0}".format(WS_PORT_NUM),
        "--JsonRpc.EngineHost=0.0.0.0",
        "--JsonRpc.EnginePort={0}".format(ENGINE_RPC_PORT_NUM),
        "--Network.ExternalIp=" + constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--Network.DiscoveryPort={0}".format(discovery_port),
        "--Network.P2PPort={0}".format(discovery_port),
        "--JsonRpc.JwtSecretFile=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--Metrics.Enabled=true",
        "--Metrics.ExposePort={0}".format(METRICS_PORT_NUM),
        "--Metrics.ExposeHost=0.0.0.0",
    ]
    if not sequencer_enabled:
        cmd.append(
            "--Optimism.SequencerUrl={0}".format(sequencer_context.beacon_http_url)
        )

    if len(existing_el_clients) > 0:
        cmd.append(
            "--Discovery.Bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
                ]
            )
        )

    # TODO: Adding the chainspec and config separately as we may want to have support for public networks and shadowforks
    cmd.append("--config=none.cfg")
    cmd.append(
        "--Init.ChainSpecPath="
        + constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
        + "/chainspec.json"
    )

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    return ServiceConfig(
        image=image,
        ports=used_ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )


def new_nethermind_launcher(
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
