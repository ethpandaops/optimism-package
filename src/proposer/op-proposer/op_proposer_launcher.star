shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

#
#  ---------------------------------- Batcher client -------------------------------------
# The Docker container runs as the "op-proposer" user so we can't write to root
PROPOSER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-proposer/op-proposer-data"

# Port IDs
PROPOSER_HTTP_PORT_ID = "http"

# Port nums
PROPOSER_HTTP_PORT_NUM = 8560


def get_used_ports():
    used_ports = {
        PROPOSER_HTTP_PORT_ID: shared_utils.new_port_spec(
            PROPOSER_HTTP_PORT_NUM,
            shared_utils.TCP_PROTOCOL,
            shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]


def launch(
    plan,
    service_name,
    image,
    cl_context,
    l1_config_env_vars,
    gs_proposer_private_key,
    l2oo_address,
):
    proposer_service_name = "{0}".format(service_name)

    config = get_proposer_config(
        plan,
        image,
        service_name,
        cl_context,
        l1_config_env_vars,
        gs_proposer_private_key,
        l2oo_address,
    )

    proposer_service = plan.add_service(service_name, config)

    proposer_http_port = proposer_service.ports[PROPOSER_HTTP_PORT_ID]
    proposer_http_url = "http://{0}:{1}".format(
        proposer_service.ip_address, proposer_http_port.number
    )

    return "op_proposer"


def get_proposer_config(
    plan,
    image,
    service_name,
    cl_context,
    l1_config_env_vars,
    gs_proposer_private_key,
    l2oo_address,
):
    cmd = [
        "op-proposer",
        "--poll-interval=12s",
        "--rpc.port=" + str(PROPOSER_HTTP_PORT_NUM),
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--l2oo-address=" + str(l2oo_address),
        "--private-key=" + gs_proposer_private_key,
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
    ]

    ports = get_used_ports()
    return ServiceConfig(
        image=image,
        ports=ports,
        cmd=cmd,
        private_ip_address_placeholder=constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
