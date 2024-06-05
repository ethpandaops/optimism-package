shared_utils = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star"
)
# input_parser = import_module("../../package_io/input_parser.star")
el_context = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/el/el_context.star"
)
el_admin_node_info = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/el/el_admin_node_info.star"
)

node_metrics = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/node_metrics_info.star"
)
constants = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/package_io/constants.star"
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

# TODO(old) Scale this dynamically based on CPUs available and Geth nodes mining
NUM_MINING_THREADS = 1

METRICS_PATH = "/debug/metrics/prometheus"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/geth/execution-data"


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


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    constants.GLOBAL_LOG_LEVEL.error: "1",
    constants.GLOBAL_LOG_LEVEL.warn: "2",
    constants.GLOBAL_LOG_LEVEL.info: "3",
    constants.GLOBAL_LOG_LEVEL.debug: "4",
    constants.GLOBAL_LOG_LEVEL.trace: "5",
}

BUILDER_IMAGE_STR = "builder"
SUAVE_ENABLED_GETH_IMAGE_STR = "suave"


def launch(
    plan,
    launcher,
    service_name,
    image,
    existing_el_clients,
):
    # log_level = input_parser.get_client_log_level_or_default(
    #     participant_log_level, global_log_level, VERBOSITY_LEVELS
    # )

    network_name = shared_utils.get_network_name(launcher.network)

    # el_min_cpu = int(el_min_cpu) if int(el_min_cpu) > 0 else EXECUTION_MIN_CPU
    # el_max_cpu = (
    #     int(el_max_cpu)
    #     if int(el_max_cpu) > 0
    #     else constants.RAM_CPU_OVERRIDES[network_name]["geth_max_cpu"]
    # )
    # el_min_mem = int(el_min_mem) if int(el_min_mem) > 0 else EXECUTION_MIN_MEMORY
    # el_max_mem = (
    #     int(el_max_mem)
    #     if int(el_max_mem) > 0
    #     else constants.RAM_CPU_OVERRIDES[network_name]["geth_max_mem"]
    # )

    # el_volume_size = (
    #     el_volume_size
    #     if int(el_volume_size) > 0
    #     else constants.VOLUME_SIZE[network_name]["geth_volume_size"]
    # )

    # cl_client_name = service_name.split("-")[3]

    config = get_config(
        plan,
        launcher.el_cl_genesis_data,
        launcher.jwt_file,
        launcher.network,
        launcher.network_id,
        image,
        service_name,
        existing_el_clients,
    )

    service = plan.add_service(service_name, config)

    enode, enr = el_admin_node_info.get_enode_enr_for_node(
        plan, service_name, RPC_PORT_ID
    )

    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    geth_metrics_info = node_metrics.new_node_metrics_info(
        service_name, METRICS_PATH, metrics_url
    )

    http_url = "http://{0}:{1}".format(service.ip_address, RPC_PORT_NUM)

    return el_context.new_el_context(
        "op-geth",
        enr,
        enode,
        service.ip_address,
        RPC_PORT_NUM,
        WS_PORT_NUM,
        ENGINE_RPC_PORT_NUM,
        http_url,
        service_name,
        [geth_metrics_info],
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
):
    init_datadir_cmd_str = "geth init --datadir={0} {1}".format(
        EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER + "/genesis.json",
    )

    discovery_port = DISCOVERY_PORT_NUM
    used_ports = get_used_ports(discovery_port)

    cmd = [
        "geth",
        # Disable path based storage scheme for electra fork and verkle
        # TODO: REMOVE Once geth default db is path based, and builder rebased
        "--networkid={0}".format(network_id),
        # "--verbosity=" + verbosity_level,
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--gcmode=archive",
        "--http",
        "--http.addr=0.0.0.0",
        "--http.vhosts=*",
        "--http.corsdomain=*",
        # WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
        #  that users should NOT store private information in these Kurtosis nodes!
        "--http.api=admin,engine,net,eth,web3,debug",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--ws.api=admin,engine,net,eth,web3,debug",
        "--ws.origins=*",
        "--allow-insecure-unlock",
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--syncmode=full",
        "--rpc.allow-unprotected-txs",
        "--metrics",
        "--metrics.addr=0.0.0.0",
        "--metrics.port={0}".format(METRICS_PORT_NUM),
        "--discovery.port={0}".format(discovery_port),
        "--port={0}".format(discovery_port),
        "--rollup.disabletxpoolgossip=true",
    ]

    if len(existing_el_clients) > 0:
        cmd.append(
            "--bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in existing_el_clients[: constants.MAX_ENODE_ENTRIES]
                ]
            )
        )

    # if len(extra_params) > 0:
    #     # this is a repeated<proto type>, we convert it into Starlark
    #     cmd.extend([param for param in extra_params])

    cmd_str = " ".join(cmd)
    if network not in constants.PUBLIC_NETWORKS:
        subcommand_strs = [
            init_datadir_cmd_str,
            cmd_str,
        ]
        command_str = " && ".join(subcommand_strs)
    else:
        command_str = cmd_str

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: el_cl_genesis_data,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }
    # if persistent:
    #     files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
    #         persistent_key="data-{0}".format(service_name),
    #         size=el_volume_size,
    #     )
    return ServiceConfig(
        image=image,
        ports=used_ports,
        cmd=[command_str],
        files=files,
        entrypoint=ENTRYPOINT_ARGS,
    )


def new_op_geth_launcher(
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
