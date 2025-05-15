_file = import_module("/src/util/file.star")
_net = import_module("/src/util/net.star")

_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_observability = import_module("/src/observability/observability.star")
_prometheus = import_module("/src/observability/prometheus/prometheus_launcher.star")


DATA_DIR = "/etc/op-supervisor"
DEPENDENCY_SET_FILE_NAME = "dependency_set.json"


def launch(
    plan,
    params,
    l1_config_env_vars,
    l2s,
    jwt_file,
    observability_helper,
):
    supervisor_l2s = [
        l2 for l2 in l2s if l2.network_id in params.superchain.participants
    ]

    config = _get_config(
        plan=plan,
        params=params,
        l1_config_env_vars=l1_config_env_vars,
        l2s=supervisor_l2s,
        jwt_file=jwt_file,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    if observability_helper.enabled:
        _observability.register_op_service_metrics_job(
            observability_helper,
            service,
        )

    return struct(service=service, l2s=supervisor_l2s)


def _get_config(
    plan,
    params,
    l1_config_env_vars,
    l2s,
    jwt_file,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    cmd = ["op-supervisor"] + params.extra_params

    # apply customizations

    if observability_helper.enabled:
        _observability.configure_op_service_metrics(cmd, ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        files={
            DATA_DIR: params.superchain.dependency_set.name,
            _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        env_vars={
            "OP_SUPERVISOR_DATADIR": "/db",
            "OP_SUPERVISOR_DEPENDENCY_SET": "{0}/{1}".format(
                DATA_DIR, params.superchain.dependency_set.path
            ),
            "OP_SUPERVISOR_L1_RPC": l1_config_env_vars["L1_RPC_URL"],
            "OP_SUPERVISOR_L2_CONSENSUS_NODES": ",".join(
                [
                    _net.service_url(
                        participant.cl_context.ip_addr,
                        params.superchain.ports[_net.INTEROP_RPC_PORT_NAME],
                    )
                    for l2 in l2s
                    for participant in l2.participants
                ]
            ),
            "OP_SUPERVISOR_L2_CONSENSUS_JWT_SECRET": _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
            "OP_SUPERVISOR_RPC_ADDR": "0.0.0.0",
            "OP_SUPERVISOR_RPC_PORT": str(params.ports[_net.RPC_PORT_NAME].number),
            "OP_SUPERVISOR_RPC_ENABLE_ADMIN": "true",
        },
        cmd=cmd,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
