ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_cl_context = import_module(
    "github.com/ethpandaops/ethereum-package/src/cl/cl_context.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

constants = import_module("../../package_io/constants.star")
observability = import_module("../../observability/observability.star")

util = import_module("../../util.star")

_net = import_module("/src/util/net.star")
_selectors = import_module("/src/l2/selectors.star")

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


# FIXME Add to input parser
def get_used_ports(discovery_port):
    used_ports = {
        BEACON_TCP_DISCOVERY_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            discovery_port, ethereum_package_shared_utils.TCP_PROTOCOL, wait=None
        ),
        BEACON_UDP_DISCOVERY_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            discovery_port, ethereum_package_shared_utils.UDP_PROTOCOL, wait=None
        ),
        constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            BEACON_HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


ENTRYPOINT_ARGS = ["sh", "-c"]

VERBOSITY_LEVELS = {
    ethereum_package_constants.GLOBAL_LOG_LEVEL.error: "ERROR",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.warn: "WARN",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.info: "INFO",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.debug: "DEBUG",
    ethereum_package_constants.GLOBAL_LOG_LEVEL.trace: "TRACE",
}


def launch(
    plan,
    params,
    network_params,
    jwt_file,
    deployment_output,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    observability_helper,
    supervisors_params,
):
    cl_log_level = ethereum_package_input_parser.get_client_log_level_or_default(
        params.log_level, log_level, VERBOSITY_LEVELS
    )

    config = get_beacon_config(
        plan=plan,
        params=params,
        network_params=network_params,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        log_level=cl_log_level,
        persistent=persistent,
        tolerations=tolerations,
        node_selectors=node_selectors,
        el_context=el_context,
        existing_cl_clients=existing_cl_clients,
        l1_config_env_vars=l1_config_env_vars,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)
    service_url = util.make_service_http_url(service)

    metrics_info = observability.new_metrics_info(
        observability_helper, service, METRICS_PATH
    )

    # response = plan.request(
    #     recipe=beacon_node_identity_recipe, service_name=service_name
    # )

    # beacon_node_enr = response["extract.enr"]
    # beacon_multiaddr = response["extract.multiaddr"]
    # beacon_peer_id = response["extract.peer_id"]

    return struct(
        service=service,
        # TODO This may be deprecated as soon as we update the codebase to use the precalculated input params
        context=ethereum_package_cl_context.new_cl_context(
            client_name="hildr",
            enr="",  # beacon_node_enr,
            ip_addr=service.ip_address,
            http_port=util.get_service_http_port_num(service),
            beacon_http_url=service_url,
            cl_nodes_metrics_info=[metrics_info],
            beacon_service_name=params.service_name,
        ),
    )


def get_beacon_config(
    plan,
    params,
    network_params,
    deployment_output,
    jwt_file,
    log_level,
    persistent,
    tolerations,
    node_selectors,
    el_context,
    existing_cl_clients,
    l1_config_env_vars,
    observability_helper,
):
    EXECUTION_ENGINE_ENDPOINT = util.make_execution_engine_url(el_context)
    EXECUTION_RPC_ENDPOINT = util.make_execution_rpc_url(el_context)

    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "--devnet",
        "--log-level={}".format(log_level),
        "--jwt-file={}".format(ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER),
        "--l1-beacon-url={0}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--l1-rpc-url={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1-ws-rpc-url={0}".format(l1_config_env_vars["L1_WS_URL"]),
        "--l2-engine-url={0}".format(EXECUTION_ENGINE_ENDPOINT),
        "--l2-rpc-url={0}".format(EXECUTION_RPC_ENDPOINT),
        "--rpc-addr=0.0.0.0",
        "--rpc-port={0}".format(params.ports[_net.BEACON_PORT_NAME].number),
        "--sync-mode=full",
        "--network="
        + "{0}/rollup-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        # TODO: support altda flags once they are implemented.
        # See https://github.com/optimism-java/hildr/issues/134
        # eg: "--altda.enabled=" + str(da_server_context.enabled),
    ]

    # configure files

    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
        ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
    }
    if persistent:
        files[BEACON_DATA_DIRPATH_ON_SERVICE_CONTAINER] = Directory(
            persistent_key="data-{0}".format(params.service_name),
            size=int(params.cl_volume_size)
            if int(params.cl_volume_size) > 0
            else constants.VOLUME_SIZE[network_params.network][
                constants.CL_TYPE.hildr + "_volume_size"
            ],
        )

    # apply customizations

    if observability_helper.enabled:
        cmd += [
            "--metrics-enable",
            "--metrics-port={0}".format(observability.METRICS_PORT_NUM),
        ]

        observability.expose_metrics_port(ports)

    if _selectors.is_sequencer(params):
        cmd.append("--sequencer-enable")

    if len(existing_cl_clients) == 1:
        cmd.append(
            "--disc-boot-nodes="
            + ",".join(
                [
                    ctx.enr
                    for ctx in existing_cl_clients[
                        : ethereum_package_constants.MAX_ENR_ENTRIES
                    ]
                ]
            )
        )

    cmd += params.extra_params

    config_args = {
        "image": params.image,
        "ports": ports,
        "cmd": cmd,
        "files": files,
        "private_ip_address_placeholder": ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        "env_vars": params.extra_env_vars,
        "labels": params.labels,
        "tolerations": tolerations,
        "node_selectors": node_selectors,
    }

    # configure resources

    if params.min_cpu > 0:
        config_args["min_cpu"] = params.min_cpu
    if params.max_cpu > 0:
        config_args["max_cpu"] = params.max_cpu
    if params.min_mem > 0:
        config_args["min_memory"] = params.min_mem
    if params.max_mem > 0:
        config_args["max_memory"] = params.max_mem

    return ServiceConfig(**config_args)
