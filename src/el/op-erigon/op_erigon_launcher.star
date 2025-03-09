_imports = import_module("/imports.star")

_ethereum_package_shared_utils = _imports.ext.ethereum_package_shared_utils
_ethereum_package_el_context = _imports.ext.ethereum_package_el_context
_ethereum_package_el_admin_node_info = _imports.ext.ethereum_package_el_admin_node_info
_ethereum_package_constants = _imports.ext.ethereum_package_constants   

_constants = _imports.load_module("src/package_io/constants.star")
_util = _imports.load_module("src/util.star")
_observability = _imports.load_module("src/observability/observability.star")

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546
DISCOVERY_PORT_NUM = 30303
ENGINE_RPC_PORT_NUM = 8551

# The min/max CPU/memory that the execution node can use
EXECUTION_MIN_CPU = 300
EXECUTION_MIN_MEMORY = 512

# The dirpath of the execution data directory on the client container
EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER = "/data/op-erigon/execution-data"


def get_used_ports(discovery_port=DISCOVERY_PORT_NUM):
    used_ports = {
        _constants.RPC_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            RPC_PORT_NUM,
            _ethereum_package_shared_utils.TCP_PROTOCOL,
            _ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        _constants.WS_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            WS_PORT_NUM, _ethereum_package_shared_utils.TCP_PROTOCOL
        ),
        _constants.TCP_DISCOVERY_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            discovery_port, _ethereum_package_shared_utils.TCP_PROTOCOL
        ),
        _constants.UDP_DISCOVERY_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            discovery_port, _ethereum_package_shared_utils.UDP_PROTOCOL
        ),
        _constants.ENGINE_RPC_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            ENGINE_RPC_PORT_NUM,
            _ethereum_package_shared_utils.TCP_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "1",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "2",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "3",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "4",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "5",
}


def launch(
    plan,
    el_args,
):
    cl_client_name = el_args.service_name.split("-")[4]

    config = _get_config(
        el_args.launcher,
        el_args.service_name,
        el_args.participant,
        el_args.persistent,
        el_args.tolerations,
        el_args.node_selectors,
        el_args.existing_el_clients,
        cl_client_name,
        el_args.sequencer_enabled,
        el_args.sequencer_context,
        el_args.observability_helper,
    )

    service = plan.add_service(el_args.service_name, config)
    http_url = _util.make_service_http_url(service, _constants.RPC_PORT_ID)

    enode, enr = _ethereum_package_el_admin_node_info.get_enode_enr_for_node(
        plan, el_args.service_name, _constants.RPC_PORT_ID
    )

    metrics_info = _observability.new_metrics_info(el_args.observability_helper, service)

    return _ethereum_package_el_context.new_el_context(
        client_name="op-erigon",
        enode=enode,
        ip_addr=service.ip_address,
        rpc_port_num=RPC_PORT_NUM,
        ws_port_num=WS_PORT_NUM,
        engine_rpc_port_num=ENGINE_RPC_PORT_NUM,
        enr=enr,
        rpc_http_url=http_url,
        service_name=el_args.service_name,
        el_metrics_info=[metrics_info],
    )


def _get_config(
    launcher,
    service_name,
    participant,
    persistent,
    tolerations,
    node_selectors,
    existing_el_clients,
    cl_client_name,
    sequencer_enabled,
    sequencer_context,
    observability_helper,
):
    discovery_port = DISCOVERY_PORT_NUM
    ports = dict(get_used_ports(discovery_port))

    subcommand_strs = []

    cmd = [
        "erigon",
        "--datadir=" + EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
        "--networkid={0}".format(launcher.network_id),
        "--http",
        "--http.addr=0.0.0.0",
        "--http.vhosts=*",
        "--http.corsdomain=*",
        "--http.api=admin,engine,net,eth,web3,debug,miner",
        "--ws",
        "--ws.port={0}".format(WS_PORT_NUM),
        "--allow-insecure-unlock",
        "--authrpc.port={0}".format(ENGINE_RPC_PORT_NUM),
        "--authrpc.addr=0.0.0.0",
        "--authrpc.vhosts=*",
        "--authrpc.jwtsecret=" + _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--nat=extip:" + _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "--rpc.allow-unprotected-txs",
        "--port={0}".format(discovery_port),
    ]

    # configure files

    files = {
        _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }
    if persistent:
        files[EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.el_volume_size)
            if int(participant.el_volume_size) > 0
            else _constants.VOLUME_SIZE[launcher.network][
                _constants.EL_TYPE.op_erigon + "_volume_size"
            ],
        )

    if launcher.network not in _ethereum_package_constants.PUBLIC_NETWORKS:
        init_datadir_cmd_str = "erigon init --datadir={0} {1}".format(
            EXECUTION_DATA_DIRPATH_ON_CLIENT_CONTAINER,
            "{0}/genesis-{1}.json".format(
                _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
                launcher.network_id,
            ),
        )

        subcommand_strs.append(init_datadir_cmd_str)

    # configure environment variables

    env_vars = dict(participant.el_extra_env_vars)

    # apply customizations

    if observability_helper.enabled:
        cmd += [
            "--metrics",
            "--metrics.addr=0.0.0.0",
            "--metrics.port={0}".format(_observability.METRICS_PORT_NUM),
        ]

        _observability.expose_metrics_port(ports)

    if not sequencer_enabled:
        cmd.append("--rollup.sequencerhttp={0}".format(sequencer_context.rpc_http_url))

    if len(existing_el_clients) > 0:
        cmd.append(
            "--bootnodes="
            + ",".join(
                [
                    ctx.enode
                    for ctx in existing_el_clients[
                        : _ethereum_package_constants.MAX_ENODE_ENTRIES
                    ]
                ]
            )
        )

    # construct command string

    cmd += participant.el_extra_params
    subcommand_strs.append(" ".join(cmd))
    command_str = " && ".join(subcommand_strs)

    config_args = {
        "image": participant.el_image,
        "ports": ports,
        "cmd": [command_str],
        "files": files,
        "entrypoint": ENTRYPOINT_ARGS,
        "private_ip_address_placeholder": _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": _ethereum_package_shared_utils.label_maker(
            client=_constants.EL_TYPE.op_erigon,
            client_type=_constants.CLIENT_TYPES.el,
            image=_util.label_from_image(participant.el_image),
            connected_client=cl_client_name,
            extra_labels=participant.el_extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
        "user": User(uid=0, gid=0),
    }

    # configure resources

    if participant.el_min_cpu > 0:
        config_args["min_cpu"] = participant.el_min_cpu
    if participant.el_max_cpu > 0:
        config_args["max_cpu"] = participant.el_max_cpu
    if participant.el_min_mem > 0:
        config_args["min_memory"] = participant.el_min_mem
    if participant.el_max_mem > 0:
        config_args["max_memory"] = participant.el_max_mem

    return ServiceConfig(**config_args)


def new_op_erigon_launcher(
    deployment_output,
    jwt_file,
    network,
    network_id,
):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network=network,
        network_id=network_id,
    )
