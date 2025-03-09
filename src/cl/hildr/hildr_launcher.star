_imports = import_module("/imports.star")

_ethereum_package_shared_utils = _imports.ext.ethereum_package_shared_utils

_ethereum_package_cl_context = _imports.ext.ethereum_package_cl_context

_ethereum_package_constants = _imports.ext.ethereum_package_constants

_ethereum_package_input_parser = _imports.ext.ethereum_package_input_parser

_constants = _imports.load_module("src/package_io/constants.star")
_observability = _imports.load_module("src/observability/observability.star")

_util = _imports.load_module("src/util.star")

#  ---------------------------------- Beacon client -------------------------------------

# The Docker container runs as the "hildr" user so we can't write to root
BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/hildr/hildr-beacon-data"
# Port IDs
BEACON_TCP_DISCOVERY_PORT_ID = "tcp-discovery"
BEACON_UDP_DISCOVERY_PORT_ID = "udp-discovery"

# Port nums
BEACON_DISCOVERY_PORT_NUM = 9003
BEACON_HTTP_PORT_NUM = 8547

METRICS_PATH = "/metrics"


def get_used_ports(discovery_port):
    used_ports = {
        BEACON_TCP_DISCOVERY_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            discovery_port, _ethereum_package_shared_utils.TCP_PROTOCOL, wait=None
        ),
        BEACON_UDP_DISCOVERY_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            discovery_port, _ethereum_package_shared_utils.UDP_PROTOCOL, wait=None
        ),
        _constants.HTTP_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
            BEACON_HTTP_PORT_NUM,
            _ethereum_package_shared_utils.TCP_PROTOCOL,
            _ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "INFO",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    _ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}


def launch(
    plan,
    cl_args,
):
    log_level = _ethereum_package_input_parser.get_client_log_level_or_default(
        cl_args.participant.cl_log_level, cl_args.global_log_level, VERBOSITY_LEVELS
    )

    config = _get_beacon_config(
        cl_args.launcher,
        cl_args.service_name,
        cl_args.participant,
        log_level,
        cl_args.persistent,
        cl_args.tolerations,
        cl_args.node_selectors,
        cl_args.el_context,
        cl_args.existing_cl_clients,
        cl_args.l1_config_env_vars,
        cl_args.sequencer_enabled,
        cl_args.observability_helper,
    )

    service = plan.add_service(cl_args.service_name, config)
    service_url = _util.make_service_http_url(service)

    metrics_info = _observability.new_metrics_info(
        cl_args.observability_helper, service, METRICS_PATH
    )

    return _ethereum_package_cl_context.new_cl_context(
        client_name="hildr",
        enr="",  # beacon_node_enr,
        ip_addr=service.ip_address,
        http_port=_util.get_service_http_port_num(service),
        beacon_http_url=service_url,
        cl_nodes_metrics_info=[metrics_info],
        beacon_service_name=cl_args.service_name,
    )


def _get_beacon_config(
    launcher,
    service_name,
    participant,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    sequencer_enabled,
    observability_helper,
):
    EXECUTION_ENGINE_ENDPOINT = _util.make_execution_engine_url(el_context)
    EXECUTION_RPC_ENDPOINT = _util.make_execution_rpc_url(el_context)

    ports = dict(get_used_ports(BEACON_DISCOVERY_PORT_NUM))

    cmd = [
        "--devnet",
        "--log.level=" + log_level,
        "--jwt-file=" + _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
        "--l1-beacon-url={0}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--l1-rpc-url={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1-ws-rpc-url={0}".format(l1_config_env_vars["L1_WS_URL"]),
        "--l2-engine-url={0}".format(EXECUTION_ENGINE_ENDPOINT),
        "--l2-rpc-url={0}".format(EXECUTION_RPC_ENDPOINT),
        "--rpc-addr=0.0.0.0",
        "--rpc-port={0}".format(BEACON_HTTP_PORT_NUM),
        "--sync-mode=full",
        "--network="
        + "{0}/rollup-{1}.json".format(
            _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            launcher.network_params.network_id,
        ),
        # TODO: support altda flags once they are implemented.
        # See https://github.com/optimism-java/hildr/issues/134
        # eg: "--altda.enabled=" + str(da_server_context.enabled),
    ]

    # configure files

    files = {
        _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: launcher.deployment_output,
        _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: launcher.jwt_file,
    }
    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(service_name),
            size=int(participant.cl_volume_size)
            if int(participant.cl_volume_size) > 0
            else _constants.VOLUME_SIZE[launcher.network][
                _constants.CL_TYPE.hildr + "_volume_size"
            ],
        )

    # configure environment variables

    env_vars = dict(participant.cl_extra_env_vars)

    # apply customizations

    if observability_helper.enabled:
        cmd += [
            "--metrics-enable",
            "--metrics-port={0}".format(_observability.METRICS_PORT_NUM),
        ]

        _observability.expose_metrics_port(ports)

    if sequencer_enabled:
        # sequencer private key can't be used by hildr yet
        # sequencer_private_key = _util.read_network_config_value(
        #     plan,
        #     launcher.deployment_output,
        #     "sequencer-{0}".format(launcher.network_params.network_id),
        #     ".privateKey",
        # )

        cmd.append("--sequencer-enable")

    if len(existing_cl_clients) == 1:
        cmd.append(
            "--disc-boot-nodes="
            + ",".join(
                [
                    ctx.enr
                    for ctx in existing_cl_clients[
                        : _ethereum_package_constants.MAX_ENR_ENTRIES
                    ]
                ]
            )
        )

    cmd += participant.cl_extra_params

    config_args = {
        "image": participant.cl_image,
        "ports": ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": _ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": env_vars,
        "labels": _ethereum_package_shared_utils.label_maker(
            client=_constants.CL_TYPE.op_node,
            client_type=_constants.CLIENT_TYPES.cl,
            image=_util.label_from_image(participant.cl_image),
            connected_client=el_context.client_name,
            extra_labels=participant.cl_extra_labels,
        ),
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    # configure resources

    if participant.cl_min_cpu > 0:
        config_args["min_cpu"] = participant.cl_min_cpu
    if participant.cl_max_cpu > 0:
        config_args["max_cpu"] = participant.cl_max_cpu
    if participant.cl_min_mem > 0:
        config_args["min_memory"] = participant.cl_min_mem
    if participant.cl_max_mem > 0:
        config_args["max_memory"] = participant.cl_max_mem

    return ServiceConfig(**config_args)


def new_hildr_launcher(deployment_output, jwt_file, network_params):
    return struct(
        deployment_output=deployment_output,
        jwt_file=jwt_file,
        network_params=network_params,
    )
