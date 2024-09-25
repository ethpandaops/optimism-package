shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

cl_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/cl/cl_context.star"
)

cl_node_ready_conditions = import_module(
    "github.com/ethpandaops/ethereum-package/src/cl/cl_node_ready_conditions.star"
)
constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

util = import_module("../../util.star")

#  ---------------------------------- Beacon client -------------------------------------

# The Docker container runs as the "hildr" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/hildr/hildr-beacon-data"
# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"
BEACON_HTTP_PORT_ID = "http"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9003
BEACON_HTTP_PORT_NUM = 8547


def get_used_ports(discovery_port):
    used_ports = {
        BEACON_TCP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.TCP_PROTOCOL, wait=None
        ),
        BEACON_UDP_DISCOVERY_PORT_ID: shared_utils.new_port_spec(
            discovery_port, shared_utils.UDP_PROTOCOL, wait=None
        ),
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
    sequencer_enabled,
):
    # beacon_node_identity_recipe = PostHttpRequestRecipe(
    #     endpoint="/",
    #     content_type="application/json",
    #     body='{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}',
    #     port_id=BEACON_HTTP_PORT_ID,
    #     extract={
    #         "enr": ".result.ENR",
    #         "multiaddr": ".result.addresses[0]",
    #         "peer_id": ".result.peerID",
    #     },
    # )

    config = get_beacon_config(
        plan,
        launcher,
        image,
        service_name,
        el_context,
        existing_cl_clients,
        l1_config_env_vars,
        # beacon_node_identity_recipe,
        sequencer_enabled,
    )

    beacon_service = plan.add_service(service_name, config)

    beacon_http_port = beacon_service.ports[BEACON_HTTP_PORT_ID]
    beacon_http_url = "http://{0}:{1}".format(
        beacon_service.ip_address, beacon_http_port.number
    )

    # response = plan.request(
    #     recipe=beacon_node_identity_recipe, service_name=service_name
    # )

    # beacon_node_enr = response["extract.enr"]
    # beacon_multiaddr = response["extract.multiaddr"]
    # beacon_peer_id = response["extract.peer_id"]

    return cl_context.new_cl_context(
        client_name="hildr",
        enr="",  # beacon_node_enr,
        ip_addr=beacon_service.ip_address,
        http_port=beacon_http_port.number,
        beacon_http_url=beacon_http_url,
        beacon_service_name=service_name,
    )


def get_beacon_config(
    plan,
    launcher,
    image,
    service_name,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    # beacon_node_identity_recipe,
    sequencer_enabled,
):
    EXECUTION_ENGINE_ENDPOINT = "http://{0}:{1}".format(
        el_context.ip_addr,
        el_context.engine_rpc_port_num,
    )
    EXECUTION_RPC_ENDPOINT = "http://{0}:{1}".format(
        el_context.ip_addr,
        el_context.rpc_port_num,
    )

    used_ports = get_used_ports(BEACON_DISCOVERY_PORT_NUM)

    cmd = [
        "--devnet",
        "--jwt-file=" + constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l1-beacon-url={0}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--l1-rpc-url={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1-ws-rpc-url={0}".format(l1_config_env_vars["L1_WS_URL"]),
        "--l2-engine-url={0}".format(EXECUTION_ENGINE_ENDPOINT),
        "--l2-rpc-url={0}".format(EXECUTION_RPC_ENDPOINT),
        "--rpc-addr=0.0.0.0",
        "--rpc-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--sync-mode=full",
        "--network="
        + constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/rollup-{0}.json".format(launcher.network_params.network_id),
    ]

    sequencer_private_key = util.read_network_config_value(
        plan,
        launcher.deployment_output,
        "sequencer-{0}".format(launcher.network_params.network_id),
        ".privateKey",
    )

    if sequencer_enabled:
        cmd.append("--sequencer-enable")

    # sequencer private key can't be used by hildr yet

    if len(existing_cl_clients) == 1:
        cmd.append(
            "--disc-boot-nodes="
            + ",".join(
                [ctx.enr for ctx in existing_cl_clients[: constants.MAX_ENR_ENTRIES]]
            )
        )

    files = {
        constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }
    ports = {}
    ports.update(used_ports)

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        # ready_conditions=ReadyCondition(
        #     recipe=beacon_node_identity_recipe,
        #     field="code",
        #     assertion="==",
        #     target_value=200,
        #     timeout="1m",
        # ),
    )


def new_hildr_launcher(deployment_output, jwt_file, network_params):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network_params=network_params,
    )
