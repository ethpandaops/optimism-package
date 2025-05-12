## Kona-node launcher
# Kona is an OP L2 Consensus client written in rust.
#
# Note: currently kona-nodes lack support for some features from the op-node such as:
# - interop syncing
# - interactions with an external sequencer
# - interactions with an op-batcher
# - external bootnode list
#
# To be able to properly spin out an L2 network containing kona consensus nodes, one must make sure to
# deploy at least one `op-node` (L2 consensus node) *before* any `kona-node` - this will allow the `op-batcher` to properly boot-up.
# Please make sure to define at least one `op-geth`/`op-node` L1/L2 couple in your network configuration before
# defining your kona-nodes.

ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_cl_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/cl/cl_context.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

constants = import_module("../../package_io/constants.star")
util = import_module("../../util.star")
observability = import_module("../../observability/observability.star")

#  ---------------------------------- Beacon client -------------------------------------

# The Docker container runs as the "kona-node" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/kona-node/beacon-data"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9003
BEACON_HTTP_PORT_NUM = 8547

METRICS_PATH = "/"


def get_used_ports(discovery_port):
    used_ports = {
        constants.TCP_DISCOVERY_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            discovery_port, ethereum_package_shared_utils.TCP_PROTOCOL, wait=None
        ),
        constants.UDP_DISCOVERY_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            discovery_port, ethereum_package_shared_utils.UDP_PROTOCOL, wait=None
        ),
        constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            BEACON_HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "v",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "vv",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "vvv",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "vvvv",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "vvvvv",
}


def launch(
    plan,
    launcher,
    service_name,
    participant,
    global_log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    sequencer_enabled,
    observability_helper,
    supervisors_params,
    da_server_context,
):
    beacon_node_identity_recipe = PostHttpRequestRecipe(
        endpoint="/",
        content_type="application/json",
        body='{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}',
        port_id=constants.HTTP_PORT_ID,
        extract={
            "enr": ".result.ENR",
            "multiaddr": ".result.addresses[0]",
            "peer_id": ".result.peerID",
        },
    )

    log_level = ethereum_package_input_parser.get_client_log_level_or_default(
        participant.cl_log_level, global_log_level, VERBOSITY_LEVELS
    )

    config = get_beacon_config(
        plan,
        launcher,
        service_name,
        participant,
        log_level,
        persistent,
        tolerations,
        node_selectors,
        el_context,
        existing_cl_clients,
        l1_config_env_vars,
        beacon_node_identity_recipe,
        sequencer_enabled,
        observability_helper,
        supervisors_params,
        da_server_context,
    )

    service = plan.add_service(service_name, config)
    service_url = util.make_service_http_url(service)

    metrics_info = observability.new_metrics_info(
        observability_helper, service, METRICS_PATH
    )

    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=service_name
    )

    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    return ethereum_package_cl_context.new_cl_context(
        client_name="kona-node",
        enr=beacon_node_enr,
        ip_addr=service.ip_address,
        http_port=util.get_service_http_port_num(service),
        beacon_http_url=service_url,
        cl_nodes_metrics_info=[metrics_info],
        beacon_service_name=service_name,
        multiaddr=beacon_multiaddr,
        peer_id=beacon_peer_id,
    )


def get_beacon_config(
    plan,
    launcher,
    service_name,
    participant,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    beacon_node_identity_recipe,
    sequencer_enabled,
    observability_helper,
    supervisors_params,
    da_server_context,
):
    ports = dict(get_used_ports(BEACON_DISCOVERY_PORT_NUM))

    EXECUTION_ENGINE_ENDPOINT = util.make_execution_engine_url(el_context)

    cmd = [
        "--l2-chain-id",
        launcher.network_params.network_id,
        "-{0}".format(log_level),
    ]

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    # Add the node command config
    cmd += [
        "node",
        "--l1-eth-rpc",
        l1_config_env_vars["L1_RPC_URL"],
        "--l1-beacon",
        l1_config_env_vars["CL_RPC_URL"],
        "--l2-engine-rpc",
        EXECUTION_ENGINE_ENDPOINT,
        "--l2-engine-jwt-secret",
        ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l2-provider-rpc",
        EXECUTION_ENGINE_ENDPOINT,
        "--l2-config-file",
        "{0}/rollup-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            launcher.network_params.network_id,
        ),
        "--p2p.advertise.ip",
        ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--p2p.advertise.tcp",
        "{0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.advertise.udp",
        "{0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.listen.ip",
        "0.0.0.0",
        "--p2p.listen.tcp",
        "{0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--p2p.listen.udp",
        "{0}".format(BEACON_DISCOVERY_PORT_NUM),
        "--rpc.addr",
        "0.0.0.0",
        "--rpc.port",
        "{0}".format(BEACON_HTTP_PORT_NUM),
        "--rpc.enable-admin",
    ]

    # configure files

    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.cl_volume_size)
            if int(participant.cl_volume_size) > 0
            else constants.VOLUME_SIZE[launcher.network][
                constants.CL_TYPE.hildr + "_volume_size"
            ],
        )

    if len(existing_cl_clients) > 0:
        cmd += [
            "--p2p.bootnodes",
            ",".join(
                [
                    ctx.enr
                    for ctx in existing_cl_clients[
                        : ethereum_package_constants.MAX_ENR_ENTRIES
                    ]
                ]
            ),
        ]

    # configure environment variables

    env_vars = dict(participant.cl_extra_env_vars)

    # TODO: handle interop args

    # TODO: handle sequencer args

    cmd += participant.cl_extra_params

    config_args = {
        "image": participant.cl_image,
        "ports": ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": ethereum_package_shared_utils.label_maker(
            client=constants.CL_TYPE.op_node,
            client_type=constants.CLIENT_TYPES.cl,
            image=util.label_from_image(participant.cl_image),
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels,
        ),
        "ready_conditions": ReadyCondition(
            recipe=beacon_node_identity_recipe,
            field="code",
            assertion="==",
            target_value=200,
            timeout="1m",
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    # configure resources

    if participant.cl_min_cpu > 0:
        config_args["min_cpu"] = participant.cl_min_cpu
    if participant.cl_max_cpu > 0:
        config_args["max_cpu"] = participant.cl_max_cpu
    if participant.cl_min_mem > 0:
        config_args["min_memory"] = participant.cl_min_mem
    if participant.cl_max_mem > 0:
        config_args["max_memory"] = participant.cl_max_mem

    return ServiceConfig(**config_args)


def new_kona_node_launcher(deployment_output, jwt_file, network_params):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network_params=network_params,
    )
