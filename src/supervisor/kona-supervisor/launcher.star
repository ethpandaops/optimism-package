_filter = import_module("/src/util/filter.star")
_file = import_module("/src/util/file.star")
_net = import_module("/src/util/net.star")

_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_observability = import_module("/src/observability/observability.star")
_prometheus = import_module("/src/observability/prometheus/prometheus_launcher.star")


DATA_DIR = "/etc/kona-supervisor"
DEPENDENCY_SET_FILE_NAME = "dependency_set.json"


def launch(
    plan,
    params,
    l1_config_env_vars,
    l2s_params,
    jwt_file,
    deployment_output,
    observability_helper,
):
    supervisor_l2s_params = [
        l2_params
        for l2_params in l2s_params
        if l2_params.network_params.network_id in params.superchain.participants
    ]

    config = _get_config(
        plan=plan,
        params=params,
        l1_config_env_vars=l1_config_env_vars,
        l2s_params=supervisor_l2s_params,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    _observability.register_op_service_metrics_job(
        observability_helper,
        service,
    )

    return struct(service=service, l2s=supervisor_l2s_params)


def _get_config(
    plan,
    params,
    l1_config_env_vars,
    l2s_params,
    jwt_file,
    deployment_output,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    cmd = list(params.extra_params)

    # apply customizations

    if observability_helper.enabled:
        _observability.configure_op_service_metrics(cmd, ports)

    # Start with default env_vars
    default_env_vars = {
        "DATADIR": "/db",
        "DEPENDENCY_SET": "{0}/{1}".format(
            DATA_DIR, params.superchain.dependency_set.path
        ),
        "ROLLUP_CONFIG_PATHS": _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/rollup-*.json",
        "L1_RPC": l1_config_env_vars["L1_RPC_URL"],
        "L2_CONSENSUS_NODES": ",".join(
            [
                _net.service_url(
                    participant.cl.service_name,
                    params.superchain.ports[_net.INTEROP_RPC_PORT_NAME],
                )
                for l2_params in l2s_params
                for participant in l2_params.participants
            ]
        ),
        "L2_CONSENSUS_JWT_SECRET": _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "RPC_ADDR": "0.0.0.0",
        "RPC_PORT": str(params.ports[_net.RPC_PORT_NAME].number),
        "RPC_ENABLE_ADMIN": "true",
    }

    # Merge in any extra_env_vars from params
    env_vars = default_env_vars | _filter.remove_none(params.extra_env_vars or {})

    return ServiceConfig(
        image=params.image,
        ports=ports,
        labels=params.labels,
        files={
            DATA_DIR: params.superchain.dependency_set.name,
            _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
            _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        env_vars=env_vars,
        cmd=cmd,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
