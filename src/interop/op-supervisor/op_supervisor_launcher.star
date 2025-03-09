_imports = import_module("/imports.star")

_ethereum_package_shared_utils = _imports.ext.ethereum_package_shared_utils
_ethereum_package_constants = _imports.ext.ethereum_package_constants

_constants = _imports.load_module("src/package_io/constants.star")
_observability = _imports.load_module("src/observability/observability.star")
_utils = _imports.load_module("src/util.star")
_interop_constants = _imports.load_module("src/interop/constants.star")


def get_used_ports():
    used_ports = {
        _constants.RPC_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            _interop_constants.SUPERVISOR_RPC_PORT_NUM,
            _ethereum_package_shared_utils.TCP_PROTOCOL,
            _ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


DATA_DIR = "/etc/op-supervisor"
DEPENDENCY_SET_FILE_NAME = "dependency_set.json"


def create_dependency_set(chains):
    result = {
        "dependencies": {
            str(chain.network_params.network_id): {
                "chainIndex": str(chain.network_params.network_id),
                "activationTime": 0,
                "historyMinTime": 0,
            }
            for chain in chains
        }
    }
    return result


def launch(
    plan,
    l1_config_env_vars,
    chains,
    l2s,
    jwt_file,
    supervisor_params,
    observability_helper,
):
    dependency_set_json = supervisor_params.dependency_set
    if not dependency_set_json:
        dependency_set = create_dependency_set(chains)
        dependency_set_json = json.encode(dependency_set)

    dependency_set_artifact = _utils.write_to_file(
        plan, dependency_set_json, DATA_DIR, DEPENDENCY_SET_FILE_NAME
    )

    config = _get_supervisor_config(
        l1_config_env_vars,
        l2s,
        jwt_file,
        dependency_set_artifact,
        supervisor_params,
        observability_helper,
    )

    supervisor_service = plan.add_service(
        _interop_constants.SUPERVISOR_SERVICE_NAME, config
    )

    _observability.register_op_service_metrics_job(
        observability_helper, supervisor_service, supervisor_params.network
    )

    return "op_supervisor"


def _get_supervisor_config(
    l1_config_env_vars,
    l2s,
    jwt_file,
    dependency_set_artifact,
    supervisor_params,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = ["op-supervisor"] + supervisor_params.extra_params

    # apply customizations

    if observability_helper.enabled:
        _observability.configure_op_service_metrics(cmd, ports)

    return ServiceConfig(
        image=supervisor_params.image,
        ports=ports,
        files={
            DATA_DIR: dependency_set_artifact,
            _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        env_vars={
            "OP_SUPERVISOR_DATADIR": "/db",
            "OP_SUPERVISOR_DEPENDENCY_SET": "{0}/{1}".format(
                DATA_DIR, DEPENDENCY_SET_FILE_NAME
            ),
            "OP_SUPERVISOR_L1_RPC": l1_config_env_vars["L1_RPC_URL"],
            "OP_SUPERVISOR_L2_CONSENSUS_NODES": ",".join(
                [
                    "ws://{0}:{1}".format(
                        participant.cl_context.ip_addr,
                        _interop_constants.INTEROP_WS_PORT_NUM,
                    )
                    for l2 in l2s
                    for participant in l2.participants
                ]
            ),
            "OP_SUPERVISOR_L2_CONSENSUS_JWT_SECRET": _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
            "OP_SUPERVISOR_RPC_ADDR": "0.0.0.0",
            "OP_SUPERVISOR_RPC_PORT": str(_interop_constants.SUPERVISOR_RPC_PORT_NUM),
            "OP_SUPERVISOR_RPC_ENABLE_ADMIN": "true",
        },
        cmd=cmd,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
