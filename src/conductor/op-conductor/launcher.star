input_parser = import_module("../package_io/input_parser.star")
observability = import_module("../observability/observability.star")
_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
constants = import_module("../package_io/constants.star")
util = import_module("../util.star")

_net = import_module("/src/util/net.star")

#
#  ---------------------------------- Op Conductor client -------------------------------------

_METRICS_PORT_NUM = "9090"
_CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-conductor/op-conductor"

_CONDUCTOR_HEALTH_CHECK_INTERVAL = 2
_CONDUCTOR_HEALTH_CHECK_MIN_PEER_COUNT = 1


def launch(
    plan,
    params,
    network_params,
    deployment_output,
    el_params,
    cl_params,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        deployment_output=deployment_output,
        el_params=el_params,
        cl_params=cl_params,
        observability_helper=observability_helper,
    )

    service = plan.add_service(
        params.service_name,
        service_config,
    )

    rpc_port = params.ports[_net.RPC_PORT_NAME]
    rpc_url = _net.service_url(service.ip_address, rpc_port)

    consensus_port = params.ports[_net.CONSENSUS_PORT_NAME]
    consensus_url = _net.service_url(service.ip_address, consensus_port)

    consensus_addr = "{0}:{1}".format(
        service.ip_address,
        consensus_port.number,
    )

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
        ),
    )


def get_service_config(
    plan,
    params,
    network_params,
    deployment_output,
    el_params,
    cl_params,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    # configure files
    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
        _CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER: Directory(
            persistent_key="datadir"
        ),
    }

    rpc_port = params.ports[_net.RPC_PORT_NAME]
    consensus_port = params.ports[_net.CONSENSUS_PORT_NAME]

    env_vars = {
        "OP_CONDUCTOR_CONSENSUS_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_CONSENSUS_ADVERTISED": "0.0.0.0",
        "OP_CONDUCTOR_CONSENSUS_PORT": str(consensus_port.number),
        "OP_CONDUCTOR_EXECUTION_RPC": _net.service_url(
            el_params.service_name, el_params.ports[_net.RPC_PORT_NAME]
        ),
        "OP_CONDUCTOR_NODE_RPC": _net.service_url(
            cl_params.service_name, cl_params.ports[_net.RPC_PORT_NAME]
        ),
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
            network_params.seconds_per_slot * 3
        ),
        "OP_CONDUCTOR_LOG_FORMAT": "logfmt",
        "OP_CONDUCTOR_LOG_LEVEL": "info",
        "OP_CONDUCTOR_ROLLUP_CONFIG": "{0}/rollup-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "OP_CONDUCTOR_PAUSED": "true" if params.paused else "false",
        # TODO Plug metrics in
        "OP_CONDUCTOR_METRICS_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_METRICS_ENABLED": "true",
        "OP_CONDUCTOR_METRICS_PORT": _METRICS_PORT_NUM,
        "OP_CONDUCTOR_RAFT_SERVER_ID": params.service_name,
        "OP_CONDUCTOR_RAFT_STORAGE_DIR": _CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "OP_CONDUCTOR_RPC_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_RPC_PORT": str(rpc_port.number),
        "OP_CONDUCTOR_RPC_ENABLE_ADMIN": "true" if params.admin else "false",
        "OP_CONDUCTOR_RPC_ENABLE_PROXY": "true" if params.proxy else "false",
    }

    return ServiceConfig(
        image=params.image,
        ports=ports,
        env_vars=env_vars,
        files=files,
        labels=params.labels,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
