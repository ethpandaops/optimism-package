ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

constants = import_module("../../package_io/constants.star")
util = import_module("../../util.star")

observability = import_module("../../observability/observability.star")
op_signer_launcher = import_module("../../signer/op_signer_launcher.star")

#
#  ---------------------------------- Batcher client -------------------------------------

SERVICE_NAME = "op-batcher"

# The Docker container runs as the "op-batcher" user so we can't write to root
BATCHER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/{0}/{0}-data".format(SERVICE_NAME)

# Port nums
BATCHER_HTTP_PORT_NUM = 8548


def get_used_ports():
    used_ports = {
        constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            BATCHER_HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]


def launch(
    plan,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    batcher_key,
    deployment_output,
    batcher_params,
    network_params,
    observability_helper,
    da_server_context,
):
    service_name = util.make_service_name(SERVICE_NAME, network_params)

    batcher_address = util.read_service_network_config_value(plan, deployment_output, "batcher", network_params, ".address")

    config = get_batcher_config(
        plan,
        image,
        el_context,
        cl_context,
        l1_config_env_vars,
        batcher_key,
        batcher_address,
        batcher_params,
        observability_helper,
        da_server_context,
    )

    service = plan.add_service(service_name, config)

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service


def get_batcher_config(
    plan,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    batcher_key,
    batcher_address,
    batcher_params,
    observability_helper,
    da_server_context,
):
    ports = dict(get_used_ports())

    cmd = [
        SERVICE_NAME,
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--poll-interval=1s",
        "--sub-safety-margin=6",
        "--num-confirmations=1",
        "--safe-abort-nonce-too-low-count=3",
        "--resubmission-timeout=30s",
        "--max-channel-duration=1",
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--private-key=" + batcher_key,
        # da commitments currently have to be sent as calldata to the batcher inbox
        "--data-availability-type="
        + ("calldata" if da_server_context.enabled else "blobs"),
        "--altda.enabled=" + str(da_server_context.enabled),
        "--altda.da-server=" + da_server_context.http_url,
        # This flag is very badly named, but is needed in order to let the da-server compute the commitment.
        # This leads to sending POST requests to /put instead of /put/<keccak256(data)>
        "--altda.da-service",
    ]

    # apply customizations

    util.disable_op_service_tls(cmd)
    util.configure_op_service_rpc(cmd, BATCHER_HTTP_PORT_NUM)
    op_signer_launcher.configure_op_signer(cmd, batcher_address)

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    cmd += batcher_params.extra_params

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
