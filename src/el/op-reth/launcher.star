ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_el_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_context.star"
)
ethereum_package_el_admin_node_info = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_admin_node_info.star"
)

ethereum_package_node_metrics = import_module(
    "github.com/ethpandaops/ethereum-package/src/node_metrics_info.star"
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

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 9551

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 100
EXECUTION_MIN_MEMORY = 256

# Paths
METRICS_PATH = "/metrics"

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/op-reth/execution-data"


def get_used_ports(discovery_port=DISCOVERY_PORT_NUM):
    used_ports = {
        constants.RPC_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            RPC_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        constants.WS_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            WS_PORT_NUM, ethereum_package_shared_utils.TCP_PROTOCOL
        ),
        constants.TCP_DISCOVERY_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            discovery_port, ethereum_package_shared_utils.TCP_PROTOCOL
        ),
        constants.UDP_DISCOVERY_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            discovery_port, ethereum_package_shared_utils.UDP_PROTOCOL
        ),
        constants.ENGINE_RPC_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM, ethereum_package_shared_utils.TCP_PROTOCOL
        ),
    }
    return used_ports


VERBOSITY_LEVELS = {
    ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "v",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "vv",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "vvv",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "vvvv",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "vvvvv",
}


def launch(
    plan,
    params,
    network_params,
    sequencer_params,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    bootnode_contexts,
    observability_helper,
    supervisors_params,
):
    el_log_level = ethereum_package_input_parser.get_client_log_level_or_default(
        params.log_level, log_level, VERBOSITY_LEVELS
    )

    config = get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        sequencer_params=sequencer_params,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level=el_log_level,
        persistent=persistent,
        tolerations=tolerations,
        node_selectors=node_selectors,
        bootnode_contexts=bootnode_contexts,
        observability_helper=observability_helper,
        supervisors_params=supervisors_params,
    )

    service = plan.add_service(params.service_name, config)
    http_url = util.make_service_http_url(service, constants.RPC_PORT_ID)

    enode = ethereum_package_el_admin_node_info.get_enode_for_node(
        plan, params.service_name, constants.RPC_PORT_ID
    )

    metrics_info = observability.new_metrics_info(
        observability_helper, service, METRICS_PATH
    )

    return ethereum_package_el_context.new_el_context(
        client_name="reth",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        rpc_http_url=http_url,
        service_name=params.service_name,
        el_metrics_info=[metrics_info],
    )


def get_service_config(
    plan,
    params,
    network_params,
    sequencer_params,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    bootnode_contexts,
    observability_helper,
    supervisors_params,
):
    discovery_port = DISCOVERY_PORT_NUM
    ports = dict(get_used_ports(discovery_port))

    cmd = [
        "node",
        "-{0}".format(log_level),
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--chain={0}".format(
            network_params.network
            if network_params.network in ethereum_package_constants.PUBLIC_NETWORKS
            else ethereum_package_constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis-{0}.json".format(network_params.network_id)
        ),
        "--http",
        "--http.port={0}".format(RPC_PORT_NUM),
        "--http.addr=0.0.0.0",
        "--http.corsdomain=*",
        # WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
        #  that users should NOT store private information in these Kurtosis nodes!
        "--http.api=admin,net,eth,web3,debug,trace",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--ws.api=net,eth",
        "--ws.origins=*",
        "--nat=extip:" + ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.jwtsecret=" + ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--authrpc.addr=0.0.0.0",
        "--discovery.port={0}".format(discovery_port),
        "--port={0}".format(discovery_port),
        "--rpc.eth-proof-window=302400",
    ]

    # configure files

    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
        ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }
    if persistent:
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(params.service_name),
            size=int(params.volume_size)
            if int(params.volume_size) > 0
            else constants.VOLUME_SIZE[network_params.network][
                constants.EL_TYPE.op_reth + "_volume_size"
            ],
        )

    # configure environment variables

    env_vars = params.extra_env_vars

    # apply customizations

    if observability_helper.enabled:
        cmd.append("--metrics=0.0.0.0:{0}".format(observability.METRICS_PORT_NUM))

        observability.expose_metrics_port(ports)

    if not sequencer_enabled:
        cmd.append("--rollup.sequencer-http={0}".format(sequencer_context.rpc_http_url))

    if len(bootnode_contexts) > 0:
        cmd.append(
            "--bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in bootnode_contexts[
                        : ethereum_package_constants.MAX_ENODE_ENTRIES
                    ]
                ]
            )
        )

    cmd += params.extra_params

    config_args = {
        "image": params.image,
        "ports": ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": params.labels,
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    # configure resources

    if params.min_cpu > 0:
        config_args["min_cpu"] = params.min_cpu
    if params.max_cpu > 0:
        config_args["max_cpu"] = params.max_cpu
    if params.min_mem > 0:
        config_args["min_memory"] = params.min_mem
    if params.max_mem > 0:
        config_args["max_memory"] = params.max_mem

    return ServiceConfig(**config_args)
