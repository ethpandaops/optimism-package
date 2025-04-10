input_parser = import_module("../../package_io/input_parser.star")
observability = import_module("../../observability/observability.star")

util = import_module("../../util.star")

#
#  ---------------------------------- Op Conductor client -------------------------------------

SERVICE_TYPE = "conductor"
SERVICE_NAME = util.make_op_service_name(SERVICE_TYPE)

CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/{0}/{0}-data".format(SERVICE_NAME)
ENTRYPOINT_ARGS = ["sh", "-c"]


def get_used_ports():
    used_ports = {}
    return used_ports


def launch(
    plan,
    cl_context,
    el_context,
    network_params,
    observability_helper,
):
    service_instance_name = util.make_service_instance_name(
        SERVICE_NAME, network_params
    )

    service = plan.add_service(
        service_instance_name,
        make_service_config(
            plan,
            cl_context,
            el_context,
            observability_helper,
        ),
    )

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service


def get_config(
    plan,
    cl_context,
    el_context,
    observability_helper,
):
    ports = dict(get_used_ports())

    # configure files
    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
    }

    execution_rpc = utils.make_http_url(
        el_context.ip_addr,
        el_context.rpc_port_num,
    )

    consensus_rpc = utils.make_http_url(
        cl_context.ip_addr,
        cl_context.rpc_port_num,
    )

    env_vars = {
            OP_CONDUCTOR_CONSENSUS_PORT: "50050"
            OP_CONDUCTOR_EXECUTION_RPC: execution_rpc
            OP_CONDUCTOR_HEALTHCHECK_INTERVAL: "1"
            OP_CONDUCTOR_HEALTHCHECK_MIN_PEER_COUNT: "2"  # set based on your internal p2p network peer count 
            OP_CONDUCTOR_HEALTHCHECK_UNSAFE_INTERVAL: "5" # recommend a 2-3x multiple of your network block time to account for temporary performance issues
            OP_CONDUCTOR_LOG_FORMAT: "logfmt"
            OP_CONDUCTOR_LOG_LEVEL: "info"
            OP_CONDUCTOR_METRICS_ADDR: 0.0.0.0
            OP_CONDUCTOR_METRICS_ENABLED: 'true'
            OP_CONDUCTOR_METRICS_PORT: '9090'
            OP_CONDUCTOR_NETWORK: network_params.network
            OP_CONDUCTOR_NODE_RPC: consensus_rpc
            OP_CONDUCTOR_RAFT_SERVER_ID: "1" 
            OP_CONDUCTOR_RAFT_STORAGE_DIR: CONDUCTOR_DATA_DIRPATH_ON_SERVICE_CONTAINER
            OP_CONDUCTOR_RPC_ADDR: "0.0.0.0"
            OP_CONDUCTOR_RPC_ENABLE_ADMIN: "true"
            OP_CONDUCTOR_RPC_ENABLE_PROXY: "true"
            OP_CONDUCTOR_RPC_PORT: "8547"
        }

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        env_vars=env_vars,
        files=files,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
