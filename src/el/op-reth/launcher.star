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

# Paths
_METRICS_PATH = "/metrics"

# The dirpath of the execution data directory on the client container
_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/op-reth/execution-data"


VERBOSITY_LEVELS = {
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "v",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "vv",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "vvv",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "vvvv",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "vvvvv",
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

    engine_rpc_port = params.ports[_net.ENGINE_RPC_PORT_NAME]
    rpc_port = params.ports[_net.RPC_PORT_NAME]
    ws_port = params.ports[_net.WS_PORT_NAME]
    rpc_url = _net.service_url(params.service_name, rpc_port)

    enode = _ethereum_package_el_admin_node_info.get_enode_for_node(
        plan, params.service_name, _net.RPC_PORT_NAME
    )

    metrics_info = _observability.new_metrics_info(
        observability_helper, service, _METRICS_PATH
    )

    return struct(
        service=service,
        context=_ethereum_package_el_context.new_el_context(
            client_name="reth",
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
        "node",
        "-{0}".format(log_level),
        "--datadir={}".format(_EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER),
        "--chain={0}".format(
            network_params.network
            if network_params.network in _ethereum_package_constants.PUBLIC_NETWORKS
            else _ethereum_package_constants.GENESIS_CONFIG_MOUNT_PATH_ON_CONTAINER
            + "/genesis-{0}.json".format(network_params.network_id)
        ),
        "--http",
        "--http.port={0}".format(ports[_net.RPC_PORT_NAME].number),
        "--http.addr=0.0.0.0",
        "--http.corsdomain=*",
        # WARNING: The admin info endpoint is enabled so that we can easily get ENR/enode, which means
        #  that users should NOT store private information in these Kurtosis nodes!
        "--http.api=admin,net,eth,web3,debug,trace",
        "--ws",
        "--ws.addr=0.0.0.0",
        "--ws.port={0}".format(ports[_net.WS_PORT_NAME].number),
        "--ws.api=net,eth",
        "--ws.origins=*",
        "--nat=extip:{}".format(
            _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER
        ),
        "--authrpc.port={0}".format(ports[_net.ENGINE_RPC_PORT_NAME].number),
        "--authrpc.jwtsecret={}".format(
            _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER
        ),
        "--authrpc.addr=0.0.0.0",
        "--discovery.port={0}".format(ports[_net.TCP_DISCOVERY_PORT_NAME].number),
        "--port={0}".format(ports[_net.TCP_DISCOVERY_PORT_NAME].number),
        "--rpc.eth-proof-window=302400",
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
                _constants.EL_TYPE.op_reth + "_volume_size"
            ],
        )

    # configure environment variables

    env_vars = dict(params.extra_env_vars)

    # apply customizations

    if observability_helper.enabled:
        cmd.append("--metrics=0.0.0.0:{0}".format(_observability.METRICS_PORT_NUM))

        _observability.expose_metrics_port(ports)

    if sequencer_params:
        cmd.append(
            "--rollup.sequencer-http={0}".format(
                _net.service_url(
                    sequencer_params.service_name,
                    sequencer_params.ports[_net.RPC_PORT_NAME],
                )
            )
        )

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
