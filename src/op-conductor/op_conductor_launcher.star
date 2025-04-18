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

#
#  ---------------------------------- Op Conductor client -------------------------------------

RPC_PORT_NUM = 8547
CONSENSUS_PORT_NUM = 50050
CONDUCTOR_METRICS_PORT_NUM = "9090"

SERVICE_TYPE = "conductor"
SERVICE_NAME = util.make_op_service_name(SERVICE_TYPE)

CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/{0}/{0}-data".format(SERVICE_NAME)

CONDUCTOR_RAFT_CONFIG_VERSION = 0  # TODO:
CONDUCTOR_RAFT_SERVER_ID = "1234"

CONSENSUS_PORT_ID = "consensus"

ENTRYPOINT_ARGS = ["sh", "-c"]


def get_used_ports():
    used_ports = {
        constants.RPC_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            RPC_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
        CONSENSUS_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            CONSENSUS_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
        ),
    }
    return used_ports


def launch(
    plan,
    cl_context,
    el_context,
    observability_helper,
    deployment_output,
    network_params,
    conductor_bootstrapped,
    index_str,
):
    service_instance_name = util.make_service_instance_name(
        SERVICE_NAME, network_params
    )

    service_name = "{0}-{1}".format(SERVICE_NAME, index_str)

    service = plan.add_service(
        service_name,
        get_config(
            plan,
            cl_context,
            el_context,
            observability_helper,
            deployment_output,
            network_params,
            conductor_bootstrapped,
        ),
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
        conductor_raft_server_id=CONDUCTOR_RAFT_SERVER_ID,
        conductor_raft_config_version=str(CONDUCTOR_RAFT_CONFIG_VERSION),
    )


def get_config(
    plan,
    cl_context,
    el_context,
    observability_helper,
    deployment_output,
    network_params,
    conductor_bootstrapped,
):
    ports = dict(get_used_ports())

    # configure files
    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
    }

    execution_rpc = util.make_http_url(
        el_context.ip_addr,
        el_context.rpc_port_num,
    )

    consensus_rpc = util.make_http_url(cl_context.ip_addr, cl_context.http_port)

    env_vars = {
        "OP_CONDUCTOR_CONSENSUS_PORT": str(CONSENSUS_PORT_NUM),
        "OP_CONDUCTOR_CONSENSUS_ADDR": ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "OP_CONDUCTOR_EXECUTION_RPC": execution_rpc,
        "OP_CONDUCTOR_HEALTHCHECK_INTERVAL": "2",
        "OP_CONDUCTOR_HEALTHCHECK_MIN_PEER_COUNT": "1",  # set based on your internal p2p network peer count
        "OP_CONDUCTOR_HEALTHCHECK_UNSAFE_INTERVAL": "30",  # recommend a 2-3x multiple of your network block time to account for temporary performance issues
        "OP_CONDUCTOR_LOG_FORMAT": "logfmt",
        "OP_CONDUCTOR_LOG_LEVEL": "info",
        "OP_CONDUCTOR_ROLLUP_CONFIG": "{0}/rollup-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "OP_CONDUCTOR_RAFT_BOOTSTRAP": "".format(
            not conductor_bootstrapped,
        ),
        "OP_CONDUCTOR_PAUSED": "".format(
            not conductor_bootstrapped,
        ),
        "OP_CONDUCTOR_METRICS_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_METRICS_ENABLED": "true",
        "OP_CONDUCTOR_METRICS_PORT": CONDUCTOR_METRICS_PORT_NUM,
        "OP_CONDUCTOR_NODE_RPC": consensus_rpc,
        "OP_CONDUCTOR_RAFT_SERVER_ID": CONDUCTOR_RAFT_SERVER_ID,
        "OP_CONDUCTOR_RAFT_STORAGE_DIR": CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "OP_CONDUCTOR_RPC_ADDR": "0.0.0.0",
        "OP_CONDUCTOR_RPC_ENABLE_ADMIN": "true",
        "OP_CONDUCTOR_RPC_ENABLE_PROXY": "true",
        "OP_CONDUCTOR_RPC_PORT": str(RPC_PORT_NUM),
    }

    image = input_parser.DEFAULT_CONDUCTOR_IMAGES[SERVICE_NAME]
    return ServiceConfig(
        image=image,
        ports=ports,
        env_vars=env_vars,
        files=files,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
