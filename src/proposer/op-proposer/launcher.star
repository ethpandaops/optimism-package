ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

constants = import_module("../../package_io/constants.star")
util = import_module("../../util.star")

observability = import_module("../../observability/observability.star")
prometheus = import_module("../../observability/prometheus/prometheus_launcher.star")

_net = import_module("/src/util/net.star")

#
#  ---------------------------------- Batcher client -------------------------------------
# The Docker container runs as the "op-proposer" user so we can't write to root
DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-proposer/op-proposer-data"

ENTRYPOINT_ARGS = ["sh", "-c"]


def launch(
    plan,
    params,
    cl_context,
    l1_config_env_vars,
    gs_proposer_private_key,
    game_factory_address,
    network_params,
    observability_helper,
):
    config = get_proposer_config(
        plan=plan,
        params=params,
        cl_context=cl_context,
        l1_config_env_vars=l1_config_env_vars,
        gs_proposer_private_key=gs_proposer_private_key,
        game_factory_address=game_factory_address,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return struct(service=service)


def get_proposer_config(
    plan,
    params,
    # TODO Replace with predefined service names & ports from the parsed network params
    cl_context,
    l1_config_env_vars,
    gs_proposer_private_key,
    game_factory_address,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "op-proposer",
        "--poll-interval=12s",
        "--rpc.port={}".format(params.ports[_net.HTTP_PORT_NAME].number),
        "--rollup-rpc={}".format(cl_context.beacon_http_url),
        "--game-factory-address={}".format(game_factory_address),
        "--private-key={}".format(gs_proposer_private_key),
        "--l1-eth-rpc={}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--allow-non-finalized=true",
        "--game-type={0}".format(params.game_type),
        "--proposal-interval={}".format(params.proposal_interval),
        "--wait-node-sync=true",
    ] + params.extra_params

    # apply customizations

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
