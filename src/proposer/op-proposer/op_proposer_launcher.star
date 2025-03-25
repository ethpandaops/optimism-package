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
SERVICE_NAME = "op-proposer"

# The Docker container runs as the "op-proposer" user so we can't write to root
DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/{0}/{0}-data".format(SERVICE_NAME)

# Port nums
HTTP_PORT_NUM = 8560


def get_used_ports():
    used_ports = {
        constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]


def launch(
    plan,
    image,
    cl_context,
    l1_config_env_vars,
    proposer_key,
    game_factory_address,
    deployment_output,
    proposer_params,
    network_params,
    observability_helper,
):
    service_name = util.make_service_name(SERVICE_NAME, network_params)

    proposer_address = util.read_service_network_config_value(plan, deployment_output, "proposer", network_params, ".address")

    config = get_proposer_config(
        plan,
        image,
        cl_context,
        l1_config_env_vars,
        proposer_key,
        proposer_address,
        game_factory_address,
        proposer_params,
        observability_helper,
    )

    service = plan.add_service(service_name, config)

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service


def get_proposer_config(
    plan,
    image,
    cl_context,
    l1_config_env_vars,
    proposer_key,
    proposer_address,
    game_factory_address,
    proposer_params,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = [
        SERVICE_NAME,
        "--poll-interval=12s",
        "--rpc.port=" + str(HTTP_PORT_NUM),
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--game-factory-address=" + str(game_factory_address),
        "--private-key=" + proposer_key,
        "--signer.endpoint=" + op_signer_launcher.ENDPOINT,
        "--signer.address=" + proposer_address,
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--allow-non-finalized=true",
        "--game-type={0}".format(proposer_params.game_type),
        "--proposal-interval=" + proposer_params.proposal_interval,
        "--wait-node-sync=true",
    ]

    # apply customizations

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    cmd += proposer_params.extra_params

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
