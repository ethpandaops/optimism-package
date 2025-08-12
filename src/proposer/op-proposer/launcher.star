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


def launch(
    plan,
    params,
    sequencers_params,
    l1_config_env_vars,
    gs_proposer_private_key,
    game_factory_address,
    network_params,
    observability_helper,
):
    config = get_service_config(
        plan=plan,
        params=params,
        sequencers_params=sequencers_params,
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


def get_service_config(
    plan,
    params,
    sequencers_params,
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
        "--rollup-rpc={}".format(
            ",".join(
                [
                    _net.service_url(
                        s.conductor_params.service_name,
                        s.conductor_params.ports[_net.RPC_PORT_NAME],
                    )
                    if s.conductor_params
                    else _net.service_url(
                        s.cl.service_name, s.cl.ports[_net.RPC_PORT_NAME]
                    )
                    for s in sequencers_params
                ]
            ),
        ),
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

    if params.pprof_enabled:
        observability.configure_op_service_pprof(cmd, ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        cmd=cmd,
        labels=params.labels,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
