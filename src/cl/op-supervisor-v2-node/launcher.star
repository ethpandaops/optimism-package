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

# This is a fake node that we don't launch
# We are using op-supervisor-v2 virtual op-node instead

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
    supervisor_context,
):

    participant_key = "{}-{}".format(network_params.network_id, params.name)
    virtual_node_rpc_port = supervisor_context.config_per_network.ports_per_participant[participant_key]
    virtual_node_port_id = "rpc-v2-{}".format(virtual_node_rpc_port)
    beacon_node_identity_recipe = PostHttpRequestRecipe(
        endpoint="/",
        content_type="application/json",
        body='{"jsonrpc":"2.0","method":"opp2p_self","params":[],"id":1}',
        port_id=virtual_node_port_id,
        extract={
            "enr": ".result.ENR",
            "multiaddr": ".result.addresses[0]",
            "peer_id": ".result.peerID",
        },
    )
    response = plan.request(
        recipe=beacon_node_identity_recipe, service_name=supervisor_context.service.name
    )

    beacon_node_enr = response["extract.enr"]
    beacon_multiaddr = response["extract.multiaddr"]
    beacon_peer_id = response["extract.peer_id"]

    service_url = _net.service_url(
        supervisor_context.service.name,
        supervisor_context.service.ports[virtual_node_port_id],
    )

    return struct(
        context=_ethereum_package_cl_context.new_cl_context(
            client_name="op-supervisor-v2-node",
            enr=beacon_node_enr,
            ip_addr=supervisor_context.service.ip_address,
            http_port=virtual_node_rpc_port,
            beacon_http_url=service_url,
            cl_nodes_metrics_info=[],
            beacon_service_name=supervisor_context.service.name,
            multiaddr=beacon_multiaddr,
            peer_id=beacon_peer_id,
        )
    )
