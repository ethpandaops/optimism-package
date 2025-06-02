input_parser = import_module("../package_io/input_parser.star")
observability = import_module("../observability/observability.star")
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
constants = import_module("../package_io/constants.star")
ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)
util = import_module("../util.star")

_net = import_module("/src/util/net.star")

#
#  ---------------------------------- Op Conductor client -------------------------------------

RPC_PORT_NUM = 8547
CONSENSUS_PORT_NUM = 50050
_METRICS_PORT_NUM = "9090"

_CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-conductor/op-conductor"

CONDUCTOR_RAFT_CONFIG_VERSION = 0
CONDUCTOR_RAFT_SERVER_ID = "1234"
CONDUCTOR_HEALTH_CHECK_INTERVAL = 2
CONDUCTOR_HEALTH_CHECK_MIN_PEER_COUNT = 1
CONDUCTOR_HEALTH_CHECK_UNSAFE_INTERVAL = 300


def get_conductor_ip_address(index_str):
    if index_str == "0":
        return "172.16.0.23"
    elif index_str == "1":
        return "172.16.0.27"
    elif index_str == "2":
        return "172.16.0.31"
    else:
        return ""


def launch(
    plan,
    params,
    network_params,
    deployment_output,
    el_context,
    cl_context,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        network_params=network_params,
        deployment_output=deployment_output,
        el_context=el_context,
        cl_context=cl_context,
        observability_helper=observability_helper,
    )

    execution_rpc = util.make_http_url(
        el_context.ip_addr,
        el_context.rpc_port_num,
    )

    consensus_rpc = util.make_http_url(cl_context.ip_addr, cl_context.http_port)

    service_config.env_vars["OP_CONDUCTOR_EXECUTION_RPC"] = execution_rpc
    service_config.env_vars["OP_CONDUCTOR_NODE_RPC"] = consensus_rpc

    service = plan.add_service(
        params.service_name,
        service_config,
    )

    http_url = "http://{0}:{1}".format(
        service.ip_address,
        RPC_PORT_NUM,
    )

    consensus_addr = "{0}:{1}".format(
        service.ip_address,
        CONSENSUS_PORT_NUM,
    )

    return struct(
        service_name=service_name,
        service_ip_address=service.ip_address,
        conductor_rpc_port=RPC_PORT_NUM,
        conductor_rpc_url=http_url,
        conductor_consensus_addr=consensus_addr,
        conductor_raft_server_id=CONDUCTOR_RAFT_SERVER_ID + index_str,
        conductor_raft_config_version=str(CONDUCTOR_RAFT_CONFIG_VERSION),
    )


def get_service_config(
    plan,
    observability_helper,
    deployment_output,
    network_params,
    conductor_bootstrapped,
    conductor_paused,
    index_str,
    image,
):
    ports = _net.ports_to_port_specs(params.ports)

    # configure files
    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
        _CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER: Directory(persistent_key="datadir")
    }

    rpc_port = params.ports[_net.RPC_PORT_NAME]
    consensus_port = params.ports[_net.CONSENSUS_PORT_NAME]

    env_vars = {
        "OP_CONDUCTOR_CONSENSUS_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_CONSENSUS_PORT": str(consensus_port.number),
        "OP_CONDUCTOR_CONSENSUS_ADVERTISED": "0.0.0.0",
        "OP_CONDUCTOR_HEALTHCHECK_INTERVAL": str(CONDUCTOR_HEALTH_CHECK_INTERVAL),
        # TODO Set based on the peer count
        "OP_CONDUCTOR_HEALTHCHECK_MIN_PEER_COUNT": str(
            CONDUCTOR_HEALTH_CHECK_MIN_PEER_COUNT
        ),
        # docs recommend a 2-3x multiple of your network block time to account for temporary performance issues
        # 
        # This might be later added as a multiplier parameter if needed
        "OP_CONDUCTOR_HEALTHCHECK_UNSAFE_INTERVAL": str(
            network_params.seconds_per_slot * 3
        ),  
        "OP_CONDUCTOR_LOG_FORMAT": "logfmt",
        "OP_CONDUCTOR_LOG_LEVEL": "info",
        "OP_CONDUCTOR_ROLLUP_CONFIG": "{0}/rollup-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "OP_CONDUCTOR_RAFT_BOOTSTRAP": "{0}".format(
            conductor_bootstrapped,
        ),
        "OP_CONDUCTOR_PAUSED": "true" if params.paused else "false",
        "OP_CONDUCTOR_METRICS_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_METRICS_ENABLED": "true",
        "OP_CONDUCTOR_METRICS_PORT": _METRICS_PORT_NUM,
        "OP_CONDUCTOR_RAFT_SERVER_ID": CONDUCTOR_RAFT_SERVER_ID + index_str,
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
        private_ip_address_placeholder=get_conductor_ip_address(index_str),
    )