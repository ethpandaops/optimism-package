_net = import_module("/src/util/net.star")

_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_observability = import_module("/src/observability/observability.star")
_builder_config = import_module("/src/test-sequencer/op-test-sequencer/builder_config.star")


def launch(
    plan,
    params,
    l1_config_env_vars,
    l2s_params,
    jwt_file,
    deployment_output,
    observability_helper,
):
    config = _get_config(
        plan=plan,
        params=params,
        l1_config_env_vars=l1_config_env_vars,
        l2s_params=l2s_params,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    _observability.register_op_service_metrics_job(
        observability_helper,
        service,
    )

    return struct(service=service, l2s=l2s_params)


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

    cmd = ["op-test-sequencer"] + params.extra_params

    # apply customizations

    if observability_helper.enabled:
        _observability.configure_op_service_metrics(cmd, ports)

    if params.pprof_enabled:
        _observability.configure_op_service_pprof(cmd, ports)

    builder_config_file = _builder_config.generate_config_file(
        plan,
        deployment_output,
        l1_rpc=l1_config_env_vars["L1_RPC_URL"],
        l2s_params=l2s_params,
    )

    return ServiceConfig(
        image=params.image,
        ports=ports,
        labels=params.labels,
        files={
            "/config": builder_config_file,
            _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
            _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        env_vars={
            "OP_TEST_SEQUENCER_RPC_JWT_SECRET": _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
            "OP_TEST_SEQUENCER_RPC_ADDR": "0.0.0.0",
            "OP_TEST_SEQUENCER_RPC_PORT": "8545",
            "OP_TEST_SEQUENCER_RPC_ENABLE_ADMIN": "true",
            "OP_TEST_SEQUENCER_BUILDERS_CONFIG": "/config/builder_config.json",
        },
        cmd=cmd,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
