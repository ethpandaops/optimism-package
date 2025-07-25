_ethereum_package_el_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_context.star"
)
_ethereum_package_el_admin_node_info = import_module(
    "github.com/ethpandaops/ethereum-package/src/el/el_admin_node_info.star"
)

_ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_selectors = import_module("/src/l2/selectors.star")

_constants = import_module("../../package_io/constants.star")

_observability = import_module("../../observability/observability.star")

# The dirpath of the execution data directory on the client container
_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/geth/execution-data"

_VERBOSITY_LEVELS = {
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "1",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "2",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "3",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "4",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "5",
}


def launch(
    plan,
    params,
    sequencer_params,
    network_params,
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
    el_log_level = _ethereum_package_input_parser.get_client_log_level_or_default(
        params.log_level, log_level, _VERBOSITY_LEVELS
    )

    el_node_selectors = _ethereum_package_input_parser.get_client_node_selectors(
        params.node_selectors,
        node_selectors,
    )

    el_tolerations = _ethereum_package_input_parser.get_client_tolerations(
        params.tolerations, [], tolerations
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
        tolerations=el_tolerations,
        node_selectors=el_node_selectors,
        bootnode_contexts=bootnode_contexts,
        observability_helper=observability_helper,
        supervisors_params=supervisors_params,
    )

    service = plan.add_service(params.service_name, config)

    engine_rpc_port = params.ports[_net.ENGINE_RPC_PORT_NAME]
    rpc_port = params.ports[_net.RPC_PORT_NAME]
    ws_port = params.ports[_net.WS_PORT_NAME]
    rpc_url = _net.service_url(params.service_name, rpc_port)

    enode, enr = _ethereum_package_el_admin_node_info.get_enode_enr_for_node(
        plan, params.service_name, _net.RPC_PORT_NAME
    )

    metrics_info = _observability.new_metrics_info(observability_helper, service)

    return struct(
        service=service,
        context=_ethereum_package_el_context.new_el_context(
            client_name="op-besu",
            enode=enode,
            ip_addr=service.ip_address,
            rpc_port_num=rpc_port.number,
            ws_port_num=ws_port.number,
            engine_rpc_port_num=engine_rpc_port.number,
            rpc_http_url=rpc_url,
            enr=enr,
            service_name=params.service_name,
            el_metrics_info=[metrics_info],
        ),
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
    ports = _net.ports_to_port_specs(params.ports)

    subcommand_strs = []

    cmd = [
        "besu",
        "--genesis-file="
        + "{0}/genesis-{1}.json".format(
            _ethereum_package_constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
            network_params.network_id,
        ),
        "--network-id={0}".format(network_params.network_id),
        "--data-path={}".format(_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER),
        "--host-allowlist=*",
        "--rpc-http-enabled=true",
        "--rpc-http-host=0.0.0.0",
        "--rpc-http-port={0}".format(ports[_net.RPC_PORT_NAME].number),
        "--rpc-http-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3,MINER",
        "--rpc-http-cors-origins=*",
        "--rpc-http-max-active-connections=300",
        "--rpc-ws-enabled=true",
        "--rpc-ws-host=0.0.0.0",
        "--rpc-ws-port={0}".format(ports[_net.WS_PORT_NAME].number),
        "--rpc-ws-api=ADMIN,CLIQUE,ETH,NET,DEBUG,TXPOOL,ENGINE,TRACE,WEB3,MINER",
        "--p2p-enabled=true",
        "--p2p-host={}".format(
            _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER
        ),
        "--p2p-port={0}".format(ports[_net.TCP_DISCOVERY_PORT_NAME].number),
        "--engine-rpc-enabled=true",
        "--engine-jwt-secret={}".format(
            _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER
        ),
        "--engine-host-allowlist=*",
        "--engine-rpc-port={0}".format(ports[_net.ENGINE_RPC_PORT_NAME].number),
        "--sync-mode=FULL",
        "--bonsai-limit-trie-logs-enabled=false",
        "--version-compatibility-protection=false",
    ]

    # configure files

    files = {
        _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
        _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if persistent:
        files[_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(params.service_name),
            size=int(params.volume_size)
            if int(params.volume_size) > 0
            else _constants.VOLUME_SIZE[network_params.network][
                _constants.EL_TYPE.op_besu + "_volume_size"
            ],
        )

    # configure environment variables

    env_vars = dict(params.extra_env_vars)

    # apply customizations

    if observability_helper.enabled:
        cmd += [
            "--metrics",
            "--metrics.addr=0.0.0.0",
            "--metrics.port={0}".format(_observability.METRICS_PORT_NUM),
        ]

        _observability.expose_metrics_port(ports)

    if len(bootnode_contexts) > 0:
        cmd.append(
            "--bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in bootnode_contexts[
                        : _ethereum_package_constants.MAX_ENODE_ENTRIES
                    ]
                ]
            )
        )

    # construct command string

    cmd += params.extra_params

    config_args = {
        "image": params.image,
        "ports": ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
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
