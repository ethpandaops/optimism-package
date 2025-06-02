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
# The Docker container runs as the "op-batcher" user so we can't write to root
BATCHER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-batcher/op-batcher-data"


def launch(
    plan,
    params,
    sequencers_params,
    l1_config_env_vars,
    gs_batcher_private_key,
    network_params,
    observability_helper,
    da_server_context,
):
    config = get_service_config(
        plan=plan,
        params=params,
        sequencers_params=sequencers_params,
        l1_config_env_vars=l1_config_env_vars,
        gs_batcher_private_key=gs_batcher_private_key,
        observability_helper=observability_helper,
        da_server_context=da_server_context,
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
    gs_batcher_private_key,
    observability_helper,
    da_server_context,
):
    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "op-batcher",
        "--l2-eth-rpc={}".format(
            ",".join(
                [
                    _net.service_url(
                        s.conductor_params.service_name,
                        s.conductor_params.ports[_net.RPC_PORT_NAME],
                    )
                    if s.conductor_params
                    else _net.service_url(
                        s.el.service_name, s.el.ports[_net.RPC_PORT_NAME]
                    )
                    for s in sequencers_params
                ]
            )
        ),
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
            )
        ),
        "--poll-interval=1s",
        "--sub-safety-margin=6",
        "--num-confirmations=1",
        "--safe-abort-nonce-too-low-count=3",
        "--resubmission-timeout=30s",
        "--rpc.addr=0.0.0.0",
        "--rpc.port={}".format(params.ports[_net.HTTP_PORT_NAME].number),
        "--rpc.enable-admin",
        "--max-channel-duration=1",
        "--l1-eth-rpc={}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--private-key={}".format(gs_batcher_private_key),
        # da commitments currently have to be sent as calldata to the batcher inbox
        "--data-availability-type={}".format(
            "calldata" if da_server_context else "blobs"
        ),
        "--altda.enabled={}".format("true" if da_server_context else "false"),
        "--altda.da-server={}".format(
            da_server_context.http_url if da_server_context else ""
        ),
        # This flag is very badly named, but is needed in order to let the da-server compute the commitment.
        # This leads to sending POST requests to /put instead of /put/<keccak256(data)>
        "--altda.da-service",
    ] + params.extra_params

    # apply customizations

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        labels=params.labels,
    )
