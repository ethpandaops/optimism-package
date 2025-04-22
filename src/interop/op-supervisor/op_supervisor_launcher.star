utils = import_module("../../util.star")

ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

observability = import_module("../../observability/observability.star")
prometheus = import_module("../../observability/prometheus/prometheus_launcher.star")

constants = import_module("../../package_io/constants.star")
interop_constants = import_module("../constants.star")


def get_used_ports():
    used_ports = {
        constants.RPC_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            interop_constants.SUPERVISOR_RPC_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


DATA_DIR = "/etc/op-supervisor"


def create_dependency_set_filename(interop_set):
    return "dependency_set-{}.json".format(interop_set.name)


def create_dependency_set(l2s):
    result = {
        "dependencies": {
            str(l2.network_id): {
                "chainIndex": str(l2.network_id),
                "activationTime": 0,
                "historyMinTime": 0,
            }
            for l2 in l2s
        }
    }
    return result


def launch(
    plan,
    interop_set,
    l1_config_env_vars,
    l2s,
    jwt_file,
    observability_helper,
):
    # First we check that the supervisor is enabled for this interop set
    if not interop_set.enabled:
        plan.print(
            "op-supervisor is not enabled for interop set {}, skipping launch".format(
                interop_set.name
            )
        )
        return None

    # Then we check that we have some participants
    if len(interop_set.participants) == 0:
        plan.print(
            "op-supervisor has no participants for interop set {}, skipping launch".format(
                interop_set.name
            )
        )
        return None

    # Now we filter out the participating L2s
    interop_set_l2s = [l2 for l2 in l2s if l2.network_id in interop_set.participants]

    # Now we create dependency set if none was provided
    dependency_set_json = interop_set.supervisor_params.dependency_set or json.encode(
        create_dependency_set(interop_set_l2s)
    )

    # And write it to an artifact
    dependency_set_filename = create_dependency_set_filename(interop_set)
    dependency_set_artifact = utils.write_to_file(
        plan, dependency_set_json, DATA_DIR, dependency_set_filename
    )

    # We create a service name based on the interop set name
    service_name = "{}-{}".format(
        interop_constants.SUPERVISOR_SERVICE_NAME, interop_set.name
    )

    config = get_supervisor_config(
        plan=plan,
        l1_config_env_vars=l1_config_env_vars,
        l2s=interop_set_l2s,
        jwt_file=jwt_file,
        dependency_set_artifact=dependency_set_artifact,
        dependency_set_filename=dependency_set_filename,
        supervisor_params=interop_set.supervisor_params,
        observability_helper=observability_helper,
    )

    service = plan.add_service(service_name, config)

    observability.register_op_service_metrics_job(
        observability_helper,
        service,
    )

    return struct(
        service=service,
        networks=interop_set_l2s,
    )


def get_supervisor_config(
    plan,
    l1_config_env_vars,
    l2s,
    jwt_file,
    dependency_set_artifact,
    dependency_set_filename,
    supervisor_params,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = ["op-supervisor"] + supervisor_params.extra_params

    # apply customizations

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    return ServiceConfig(
        image=supervisor_params.image,
        ports=ports,
        files={
            DATA_DIR: dependency_set_artifact,
            ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        env_vars={
            "OP_SUPERVISOR_DATADIR": "/db",
            "OP_SUPERVISOR_DEPENDENCY_SET": "{0}/{1}".format(
                DATA_DIR, dependency_set_filename
            ),
            "OP_SUPERVISOR_L1_RPC": l1_config_env_vars["L1_RPC_URL"],
            "OP_SUPERVISOR_L2_CONSENSUS_NODES": ",".join(
                [
                    "ws://{0}:{1}".format(
                        participant.cl_context.ip_addr,
                        interop_constants.INTEROP_WS_PORT_NUM,
                    )
                    for l2 in l2s
                    for participant in l2.participants
                ]
            ),
            "OP_SUPERVISOR_L2_CONSENSUS_JWT_SECRET": ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
            "OP_SUPERVISOR_RPC_ADDR": "0.0.0.0",
            "OP_SUPERVISOR_RPC_PORT": str(interop_constants.SUPERVISOR_RPC_PORT_NUM),
            "OP_SUPERVISOR_RPC_ENABLE_ADMIN": "true",
        },
        cmd=cmd,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
