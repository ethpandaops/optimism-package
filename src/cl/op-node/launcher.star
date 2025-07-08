_ethereum_package_cl_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/cl/cl_context.star"
)

_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")

_constants = import_module("../../package_io/constants.star")
_util = import_module("../../util.star")
_observability = import_module("../../observability/observability.star")

#  ---------------------------------- Beacon client -------------------------------------

# The Docker container runs as the "op-node" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-node/op-node-beacon-data"

# TODO This block seems repetitive, at least for all OP services
VERBOSITY_LEVELS = {
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "INFO",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}


def launch(
    plan,
    params,
    network_params,
    da_params,
    supervisors_params,
    conductor_params,
    is_sequencer,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    cl_contexts,
    l1_config_env_vars,
    observability_helper,
):
    beacon_node_identity_recipe = PostHttpRequestRecipe(
        endpoint="/",
        content_type="application/json",
        body='{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}',
        port_id=_net.RPC_PORT_NAME,
        extract={
            "enr": ".result.ENR",
            "multiaddr": ".result.addresses[0]",
            "peer_id": ".result.peerID",
        },
    )

    cl_log_level = _ethereum_package_input_parser.get_client_log_level_or_default(
        params.log_level, log_level, VERBOSITY_LEVELS
    )

    cl_node_selectors = _ethereum_package_input_parser.get_client_node_selectors(
        params.node_selectors,
        node_selectors,
    )

    cl_tolerations = _ethereum_package_input_parser.get_client_tolerations(
        params.tolerations, [], tolerations
    )

    config = get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        da_params=da_params,
        supervisors_params=supervisors_params,
        conductor_params=conductor_params,
        is_sequencer=is_sequencer,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        beacon_node_identity_recipe=beacon_node_identity_recipe,
        log_level=cl_log_level,
        persistent=persistent,
        tolerations=cl_tolerations,
        node_selectors=cl_node_selectors,
        el_context=el_context,
        cl_contexts=cl_contexts,
        l1_config_env_vars=l1_config_env_vars,
        observability_helper=observability_helper,
    )

    rpc_port = params.ports[_net.RPC_PORT_NAME]

    service = plan.add_service(params.service_name, config)
    service_url = _net.service_url(params.service_name, rpc_port)

    metrics_info = _observability.new_metrics_info(observability_helper, service)

    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=params.service_name
    )

    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    return struct(
        service=service,
        context=_ethereum_package_cl_context.new_cl_context(
            client_name="op-node",
            enr=beacon_node_enr,
            ip_addr=service.ip_address,
            http_port=rpc_port.number,
            beacon_http_url=service_url,
            cl_nodes_metrics_info=[metrics_info],
            beacon_service_name=params.service_name,
            multiaddr=beacon_multiaddr,
            peer_id=beacon_peer_id,
        ),
    )


def get_service_config(
    plan,
    params,
    network_params,
    da_params,
    supervisors_params,
    conductor_params,
    jwt_file,
    deployment_output,
    is_sequencer,
    beacon_node_identity_recipe,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    cl_contexts,
    l1_config_env_vars,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    EXECUTION_ENGINE_ENDPOINT = _util.make_execution_engine_url(el_context)

    rpc_port_number = params.ports[_net.RPC_PORT_NAME].number
    tcp_discovery_port_number = params.ports[_net.TCP_DISCOVERY_PORT_NAME].number
    udp_discovery_port_number = params.ports[_net.UDP_DISCOVERY_PORT_NAME].number

    cmd = [
        "op-node",
        "--log.level=" + log_level,
        "--l2={0}".format(EXECUTION_ENGINE_ENDPOINT),
        "--l2.jwt-secret=" + _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--verifier.l1-confs=1",
        "--rollup.config="
        + "{0}/rollup-{1}.json".format(
            _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "--rpc.addr=0.0.0.0",
        "--rpc.port={0}".format(rpc_port_number),
        "--rpc.enable-admin",
        "--l1={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1.rpckind={0}".format(l1_config_env_vars["L1_RPC_KIND"]),
        "--l1.beacon={0}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--p2p.advertise.ip={0}".format(
            _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER
        ),
        "--p2p.advertise.tcp={0}".format(tcp_discovery_port_number),
        "--p2p.advertise.udp={0}".format(udp_discovery_port_number),
        "--p2p.listen.ip=0.0.0.0",
        "--p2p.listen.tcp={0}".format(tcp_discovery_port_number),
        "--p2p.listen.udp={0}".format(udp_discovery_port_number),
        "--safedb.path={0}".format(BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER),
        "--altda.enabled={}".format("true" if da_params else "false"),
        "--altda.da-server={}".format(
            _net.service_url(
                da_params.service_name, da_params.ports[_net.HTTP_PORT_NAME]
            )
            if da_params
            else ""
        ),
    ]

    supervisor_params = _filter.first(supervisors_params)

    # configure files

    files = {
        _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: Directory(
            artifact_names=[
                deployment_output,
                supervisor_params.superchain.dependency_set.name,
            ]
        )
        if supervisor_params
        else deployment_output,
        _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }

    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(params.service_name),
            size=int(params.volume_size)
            if int(params.volume_size) > 0
            else _constants.VOLUME_SIZE[network_params.network][
                _constants.CL_TYPE.op_node + "_volume_size"
            ],
        )

    # configure environment variables

    env_vars = dict(params.extra_env_vars)

    # apply customizations

    if observability_helper.enabled:
        _observability.configure_op_service_metrics(cmd, ports)

    if params.pprof_enabled:
        _observability.configure_op_service_pprof(cmd, ports)

    if supervisor_params:
        interop_rpc_port = supervisor_params.superchain.ports[
            _net.INTEROP_RPC_PORT_NAME
        ]
        ports[_net.INTEROP_RPC_PORT_NAME] = _net.port_to_port_spec(interop_rpc_port)

        env_vars.update(
            {
                "OP_NODE_INTEROP_RPC_ADDR": "0.0.0.0",
                "OP_NODE_INTEROP_RPC_PORT": str(interop_rpc_port.number),
                "OP_NODE_INTEROP_JWT_SECRET": _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
                "OP_NODE_INTEROP_DEPENDENCY_SET": "{0}/{1}".format(
                    _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
                    supervisor_params.superchain.dependency_set.path,
                ),
            }
        )

    if is_sequencer:
        sequencer_private_key = _util.read_network_config_value(
            plan,
            deployment_output,
            "sequencer-{0}".format(network_params.network_id),
            ".privateKey",
        )

        cmd += [
            "--p2p.sequencer.key=" + sequencer_private_key,
            "--sequencer.enabled",
            "--sequencer.l1-confs=2",
        ]

    if conductor_params:
        cmd += [
            "--conductor.enabled=true",
            "--conductor.rpc={0}".format(
                _net.service_url(
                    conductor_params.service_name,
                    conductor_params.ports[_net.RPC_PORT_NAME],
                )
            ),
            "--sequencer.stopped=true",
        ]

    if len(cl_contexts) > 0:
        cmd.append(
            "--p2p.bootnodes="
            + ",".join(
                [
                    ctx.enr
                    for ctx in cl_contexts[
                        : _ethereum_package_constants.MAX_ENR_ENTRIES
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

    if params.min_cpu > 0:
        config_args["min_cpu"] = params.min_cpu
    if params.max_cpu > 0:
        config_args["max_cpu"] = params.max_cpu
    if params.min_mem > 0:
        config_args["min_memory"] = params.min_mem
    if params.max_mem > 0:
        config_args["max_memory"] = params.max_mem

    return ServiceConfig(**config_args)
