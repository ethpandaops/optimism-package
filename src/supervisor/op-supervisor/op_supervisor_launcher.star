utils = import_module("../../util.star")

ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

# Port IDs
SUPERVISOR_RPC_PORT_ID = "rpc"

# Port nums
SUPERVISOR_RPC_PORT_NUM = 8545

def get_used_ports():
    used_ports = {
        SUPERVISOR_RPC_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            SUPERVISOR_RPC_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports

DATA_DIR = "/etc/op-supervisor"
DEPENDENCY_SET_FILE_NAME = "dependency_set.json"

def launch(
    plan,
    service_name,
    all_participants,
    supervisor_params,
):
    dependency_set_artifact = utils.write_to_file(
        plan,
        supervisor_params.dependency_set,
        DATA_DIR,
        DEPENDENCY_SET_FILE_NAME
    )

    config = get_supervisor_config(
        plan,
        service_name,
        all_participants,
        dependency_set_artifact,
        supervisor_params,
    )

    supervisor_service = plan.add_service(service_name, config)

    return "op_supervisor"

def get_supervisor_config(
    plan,
    service_name,
    all_participants,
    dependency_set_artifact,
    supervisor_params,
):
    cmd = ["op-supervisor"] + supervisor_params.extra_params

    ports = get_used_ports()
    return ServiceConfig(
        image=supervisor_params.image,
        ports=ports,
        files={
            DATA_DIR: dependency_set_artifact
        },
        env_vars={
            "OP_SUPERVISOR_DATADIR": "/db",
            "OP_SUPERVISOR_DEPENDENCY_SET": "{0}/{1}".format(DATA_DIR, DEPENDENCY_SET_FILE_NAME),
            "OP_SUPERVISOR_L2_RPCS": ",".join([str(participant.el_context.rpc_http_url) for participant in all_participants]),
            "OP_SUPERVISOR_RPC_ADDR": "0.0.0.0",
            "OP_SUPERVISOR_RPC_PORT": str(SUPERVISOR_RPC_PORT_NUM),
            "OP_SUPERVISOR_RPC_ENABLE_ADMIN": "true"
        },
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER
    )
