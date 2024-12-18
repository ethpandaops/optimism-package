utils = import_module("../../util.star")

ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

#
#  ---------------------------------- Batcher client -------------------------------------
# The Docker container runs as the "op-supervisor" user so we can't write to root
SUPERVISOR_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-supervisor/op-supervisor-data"

# Port IDs
SUPERVISOR_HTTP_PORT_ID = "http"

# Port nums
SUPERVISOR_HTTP_PORT_NUM = 8548

def get_used_ports():
    used_ports = {
        SUPERVISOR_HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            SUPERVISOR_HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports

ENTRYPOINT_ARGS = ["sh", "-c"]

DATA_DIR = "/etc/op-supervisor"
DEPENDENCY_SET_FILE_NAME = "dependency_set.json"
DEPENDENCY_SET_FILE_PATH = "{0}/{1}".format(DATA_DIR, DEPENDENCY_SET_FILE_NAME)

def launch(
    plan,
    service_name,
    all_participants,
    supervisor_params,
):
    # write dependency set to a file
    dependency_set_artifact = utils.write_to_file(
        plan,
        DATA_DIR,
        DEPENDENCY_SET_FILE_NAME,
        supervisor_params.dependency_set
    )

    config = get_supervisor_config(
        plan,
        service_name,
        all_participants,
        dependency_set_artifact,
        supervisor_params,
    )

    supervisor_service = plan.add_service(service_name, config)

    supervisor_http_port = supervisor_service.ports[SUPERVISOR_HTTP_PORT_ID]
    supervisor_http_url = "http://{0}:{1}".format(
        supervisor_service.ip_address, supervisor_http_port.number
    )

    return "op_supervisor"


def get_supervisor_config(
    plan,
    service_name,
    all_participants,
    dependency_set_artifact,
    supervisor_params,
):
    cmd = [
        "op-supervisor",
        "--data-dir=" + SUPERVISOR_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--dependency-set=" + supervisor_params.dependency_set,
        "--l2-rpcs=" + ",".join([str(participant.el_context.rpc_http_url) for participant in all_participants]),
        "--rpc.addr=0.0.0.0",
        "--rpc.port=" + str(SUPERVISOR_HTTP_PORT_NUM),
        "--rpc.enable-admin",
    ]

    cmd += supervisor_params.extra_params

    ports = get_used_ports()
    return ServiceConfig(
        image=supervisor_params.image,
        ports=ports,
        files={
            DEPENDENCY_SET_FILE_PATH: dependency_set_artifact
        },
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
