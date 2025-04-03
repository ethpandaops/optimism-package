ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

observability = import_module("../../observability/observability.star")
prometheus = import_module("../../observability/prometheus/prometheus_launcher.star")

interop_constants = import_module("../../interop/constants.star")
util = import_module("../../util.star")

#
#  ---------------------------------- Challenger client -------------------------------------
CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-challenger/op-challenger-data"
ENTRYPOINT_ARGS = ["sh", "-c"]


def get_used_ports():
    used_ports = {}
    return used_ports


def launch(
    plan,
    l2_num,
    service_name,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    deployment_output,
    network_params,
    challenger_params,
    interop_params,
    observability_helper,
):
    return plan.add_service(service_name, ServiceConfig(
        cmd = [cmd]
        env_vars = {
            OP_CONDUCTOR_CONSENSUS_ADDR: '<raft url or ip>'
            OP_CONDUCTOR_CONSENSUS_PORT: '50050'
            OP_CONDUCTOR_EXECUTION_RPC: '<op-geth url or ip>:8545'
            OP_CONDUCTOR_HEALTHCHECK_INTERVAL: '1'
            OP_CONDUCTOR_HEALTHCHECK_MIN_PEER_COUNT: '2'  # set based on your internal p2p network peer count 
            OP_CONDUCTOR_HEALTHCHECK_UNSAFE_INTERVAL: '5' # recommend a 2-3x multiple of your network block time to account for temporary performance issues
            OP_CONDUCTOR_LOG_FORMAT: 'logfmt'
            OP_CONDUCTOR_LOG_LEVEL: 'info'
            # OP_CONDUCTOR_METRICS_ADDR: 0.0.0.0
            # OP_CONDUCTOR_METRICS_ENABLED: 'true'
            # OP_CONDUCTOR_METRICS_PORT: '7300'
            OP_CONDUCTOR_NETWORK: '<network>'
            OP_CONDUCTOR_NODE_RPC: '<op-node url or ip>:8545'
            OP_CONDUCTOR_RAFT_SERVER_ID: 'unique raft server id'
            OP_CONDUCTOR_RAFT_STORAGE_DIR: CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER
            OP_CONDUCTOR_RPC_ADDR: '0.0.0.0'
            OP_CONDUCTOR_RPC_ENABLE_ADMIN: 'true'
            OP_CONDUCTOR_RPC_ENABLE_PROXY: 'true'
            OP_CONDUCTOR_RPC_PORT: '8547'
        }
    ))