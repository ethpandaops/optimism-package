ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

input_parser = import_module("../../package_io/input_parser.star")
constants = import_module("../../package_io/constants.star")
util = import_module("../../util.star")

observability = import_module("../../observability/observability.star")
op_signer_launcher = import_module("../../signer/op_signer_launcher.star")

#
#  ---------------------------------- Proposer client -------------------------------------
SERVICE_TYPE = "proposer"
SERVICE_NAME = util.make_op_service_name(SERVICE_TYPE)

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
    cl_context,
    l1_config_env_vars,
    signer_context,
    game_factory_address,
    proposer_params,
    network_params,
    observability_helper,
    conductor_contexts,
):
    service_instance_name = util.make_service_instance_name(
        SERVICE_NAME, network_params
    )

    service = plan.add_service(
        service_instance_name,
        make_service_config(
            plan,
            cl_context,
            l1_config_env_vars,
            signer_context,
            game_factory_address,
            proposer_params,
            observability_helper,
            conductor_contexts,
        ),
    )

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service


def make_service_config(
    plan,
    cl_context,
    l1_config_env_vars,
    signer_context,
    game_factory_address,
    proposer_params,
    observability_helper,
    conductor_contexts,
):
    ports = dict(get_used_ports())

    cmd = [
        SERVICE_NAME,
        "--poll-interval=12s",
        "--rpc.port=" + str(HTTP_PORT_NUM),
        "--rollup-rpc="
        + "{0},{1},{2}".format(
            conductor_contexts[0].conductor_rpc_url,
            conductor_contexts[1].conductor_rpc_url,
            conductor_contexts[2].conductor_rpc_url,
        )
        if len(conductor_contexts) > 0
        else "--rollup-rpc=" + cl_context.beacon_http_url,
        "--game-factory-address=" + str(game_factory_address),
        "--private-key=" + signer_context.clients[SERVICE_TYPE].key,
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--allow-non-finalized=true",
        "--game-type={0}".format(proposer_params.game_type),
        "--proposal-interval=" + proposer_params.proposal_interval,
        "--wait-node-sync=true",
    ]

    files = {}

    # apply customizations

    op_signer_launcher.configure_op_signer(cmd, files, signer_context, SERVICE_TYPE)

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    cmd += proposer_params.extra_params

    # legacy default image logic
    image = (
        proposer_params.image
        if proposer_params.image != ""
        else input_parser.DEFAULT_PROPOSER_IMAGES[SERVICE_NAME]
    )

    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        files=files,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
