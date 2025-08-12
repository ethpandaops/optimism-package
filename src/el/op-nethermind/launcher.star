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

_constants = import_module("../../package_io/constants.star")

_observability = import_module("../../observability/observability.star")


# The dirpath of the execution data directory on the client container
_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/nethermind/execution-data"


_VERBOSITY_LEVELS = {
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "error",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "warn",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "info",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "debug",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "trace",
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

    enode = _ethereum_package_el_admin_node_info.get_enode_for_node(
        plan, params.service_name, _net.RPC_PORT_NAME
    )

    metrics_info = _observability.new_metrics_info(observability_helper, service)

    return struct(
        service=service,
        context=_ethereum_package_el_context.new_el_context(
            client_name="op-nethermind",
            enode=enode,
            ip_addr=service.ip_address,
            rpc_port_num=rpc_port.number,
            ws_port_num=ws_port.number,
            engine_rpc_port_num=engine_rpc_port.number,
            rpc_http_url=rpc_url,
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

    cmd = [
        "--log={}".format(log_level),
        "--datadir={}".format(_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER),
        "--Init.WebSocketsEnabled=true",
        "--JsonRpc.Enabled=true",
        "--JsonRpc.EnabledModules=net,eth,consensus,subscribe,web3,admin,miner",
        "--JsonRpc.Host=0.0.0.0",
        "--JsonRpc.Port={0}".format(ports[_net.RPC_PORT_NAME].number),
        "--JsonRpc.WebSocketsPort={0}".format(ports[_net.WS_PORT_NAME].number),
        "--JsonRpc.EngineHost=0.0.0.0",
        "--JsonRpc.EnginePort={0}".format(ports[_net.ENGINE_RPC_PORT_NAME].number),
        "--Network.ExternalIp={}".format(
            _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER
        ),
        "--Network.DiscoveryPort={0}".format(
            ports[_net.TCP_DISCOVERY_PORT_NAME].number
        ),
        "--Network.P2PPort={0}".format(ports[_net.TCP_DISCOVERY_PORT_NAME].number),
        "--JsonRpc.JwtSecretFile={}".format(
            _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER
        ),
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
                _constants.EL_TYPE.op_nethermind + "_volume_size"
            ],
        )

    # configure environment variables

    env_vars = dict(params.extra_env_vars)

    # apply customizations

    if observability_helper.enabled:
        cmd += [
            "--Metrics.Enabled=true",
            "--Metrics.ExposeHost=0.0.0.0",
            "--Metrics.ExposePort={0}".format(_observability.METRICS_PORT_NUM),
        ]

        _observability.expose_metrics_port(ports)

    if sequencer_params:
        cmd.append(
            "--Optimism.SequencerUrl={0}".format(
                _net.service_url(
                    sequencer_params.el.service_name,
                    sequencer_params.el.ports[_net.RPC_PORT_NAME],
                )
            )
        )

    if len(bootnode_contexts) > 0:
        cmd.append(
            "--Discovery.Bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in bootnode_contexts[
                        : _ethereum_package_constants.MAX_ENODE_ENTRIES
                    ]
                ]
            )
        )

    # TODO: Adding the chainspec and config separately as we may want to have support for public networks and shadowforks
    cmd.append("--config=none.cfg")
    cmd.append(
        "--Init.ChainSpecPath="
        + "{0}/chainspec-{1}.json".format(
            _ethereum_package_constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER,
            network_params.network_id,
        ),
    )

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
