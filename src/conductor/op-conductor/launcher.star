_observability = import_module("/src/observability/observability.star")
_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")

#
#  ---------------------------------- Op Conductor client -------------------------------------

_CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-conductor/op-conductor"

_CONDUCTOR_HEALTH_CHECK_INTERVAL = 2
_CONDUCTOR_HEALTH_CHECK_MIN_PEER_COUNT = 1


def launch(
    plan,
    params,
    network_params,
    supervisors_params,
    sidecar_context,
    deployment_output,
    el_params,
    cl_params,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        supervisors_params=supervisors_params,
        sidecar_context=sidecar_context,
        deployment_output=deployment_output,
        el_params=el_params,
        cl_params=cl_params,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    rpc_port = params.ports[_net.RPC_PORT_NAME]
    rpc_url = _net.service_url(service.ip_address, rpc_port)

    consensus_port = params.ports[_net.CONSENSUS_PORT_NAME]
    consensus_url = _net.service_url(service.ip_address, consensus_port)

    metrics_info = _observability.new_metrics_info(observability_helper, service)

    return struct(
        service=service,
        context=struct(
            service_name=params.service_name,
            service_ip_address=service.ip_address,
            conductor_rpc_port=rpc_port.number,
            conductor_rpc_url=rpc_url,
            conductor_consensus_port=consensus_port.number,
            conductor_consensus_url=consensus_url,
            conductor_raft_server_id=params.service_name,
            conductor_metrics_info=[metrics_info],
        ),
    )


def get_service_config(
    plan,
    params,
    network_params,
    supervisors_params,
    sidecar_context,
    deployment_output,
    el_params,
    cl_params,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    # configure files
    files = {
        _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
        _CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER: Directory(
            persistent_key="datadir"
        ),
    }

    rpc_port = params.ports[_net.RPC_PORT_NAME]
    consensus_port = params.ports[_net.CONSENSUS_PORT_NAME]

    env_vars = {
        "OP_CONDUCTOR_CONSENSUS_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_CONSENSUS_ADVERTISED": "{}:{}".format(
            params.service_name, consensus_port.number
        ),
        "OP_CONDUCTOR_CONSENSUS_PORT": str(consensus_port.number),
        "OP_CONDUCTOR_EXECUTION_RPC": sidecar_context.rpc_http_url
        if sidecar_context
        else _net.service_url(
            el_params.service_name, el_params.ports[_net.RPC_PORT_NAME]
        ),
        "OP_CONDUCTOR_NODE_RPC": _net.service_url(
            cl_params.service_name, cl_params.ports[_net.RPC_PORT_NAME]
        ),
        "OP_CONDUCTOR_ROLLUP_BOOST_ENABLED": "true" if sidecar_context else "false",
        # This might also become a parameter
        "OP_CONDUCTOR_HEALTHCHECK_INTERVAL": str(_CONDUCTOR_HEALTH_CHECK_INTERVAL),
        # This might also become a parameter
        "OP_CONDUCTOR_HEALTHCHECK_MIN_PEER_COUNT": str(
            _CONDUCTOR_HEALTH_CHECK_MIN_PEER_COUNT
        ),
        # docs recommend a 2-3x multiple of your network block time to account for temporary performance issues
        #
        # TODO This might be later added as a multiplier parameter if needed
        "OP_CONDUCTOR_HEALTHCHECK_UNSAFE_INTERVAL": str(
            network_params.seconds_per_slot * 2 + 1
        ),
        "OP_CONDUCTOR_LOG_FORMAT": "logfmt",
        "OP_CONDUCTOR_LOG_LEVEL": "info",
        "OP_CONDUCTOR_ROLLUP_CONFIG": "{0}/rollup-{1}.json".format(
            _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "OP_CONDUCTOR_PAUSED": "true" if params.paused else "false",
        "OP_CONDUCTOR_RAFT_BOOTSTRAP": "true" if params.bootstrap else "false",
        "OP_CONDUCTOR_RAFT_SERVER_ID": params.service_name,
        "OP_CONDUCTOR_RAFT_STORAGE_DIR": _CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "OP_CONDUCTOR_RPC_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_RPC_PORT": str(rpc_port.number),
        "OP_CONDUCTOR_RPC_ENABLE_ADMIN": "true" if params.admin else "false",
        "OP_CONDUCTOR_RPC_ENABLE_PROXY": "true" if params.proxy else "false",
        "OP_CONDUCTOR_SUPERVISOR_RPC": _filter.first(
            [
                _net.service_url(s.service_name, s.ports[_net.RPC_PORT_NAME])
                for s in supervisors_params
            ]
        )
        or "",
    }

    if observability_helper.enabled:
        _observability.configure_op_service_metrics(cmd, ports)

    if params.pprof_enabled:
        _observability.configure_op_service_pprof(cmd, ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        env_vars=env_vars,
        files=files,
        labels=params.labels,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
