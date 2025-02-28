ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

observability = import_module("../../observability/observability.star")
prometheus = import_module("../../observability/prometheus/prometheus_launcher.star")

interop_constants = import_module("../../interop/constants.star")
util = import_module("../../util.star")

#
#  ---------------------------------- Challenger client -------------------------------------
CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-challenger/op-challenger-data"
ENTRYPOINT_ARGS = ["sh", "-c"]


def get_used_ports():
    used_ports = {}
    return used_ports


def launch(
    plan,
    l2_num,
    service_name,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    deployment_output,
    network_params,
    challenger_params,
    interop_params,
    observability_helper,
    prestates_url,
):
    """Launches the op-challenger service

    Args:
        plan: The plan object.
        l2_num (int): The L2 chain index.
        service_name (str): The name of the service.
        image (str): The image to use for the service.
        el_context (dict): The EL context.
        cl_context (dict): The CL context.
        l1_config_env_vars (dict): The L1 config environment variables.
        deployment_output (dict): The deployment output.
        network_params (dict): The network parameters.
        challenger_params (dict): The challenger parameters.
        interop_params (dict): The interop parameters.
        observability_helper (dict): The observability helper.
        prestates_url (str): The prestate URL.
    Returns:
        str: The name of the challenger service.
    """
    challenger_service_name = "{0}".format(service_name)

    config = get_challenger_config(
        plan = plan,
        l2_num = l2_num,
        image = image,
        el_context = el_context,
        cl_context = cl_context,
        l1_config_env_vars = l1_config_env_vars,
        deployment_output = deployment_output,
        network_params = network_params,
        challenger_params = challenger_params,
        interop_params = interop_params,
        observability_helper = observability_helper,
        prestates_url = prestates_url,
    )

    challenger_service = plan.add_service(service_name, config)

    observability.register_op_service_metrics_job(
        observability_helper, challenger_service
    )

    return challenger_service_name


def get_challenger_config(
    plan,
    l2_num,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    deployment_output,
    network_params,
    challenger_params,
    interop_params,
    observability_helper,
    prestates_url,
):
    """Gets the challenger config

    Args:
        plan (dict): The plan object.
        l2_num (int): The L2 chain index.
        image (str): The image to use for the service.
        el_context (dict): The EL context.
        cl_context (dict): The CL context.
        l1_config_env_vars (dict): The L1 config environment variables.
        deployment_output (dict): The deployment output.
        network_params (dict): The network parameters.
        challenger_params (dict): The challenger parameters.
        interop_params (dict): The interop parameters.
        observability_helper (dict): The observability helper.
        prestates_url (str): The prestate URL.
    Returns:
        ServiceConfig: The challenger config.
    """
    ports = dict(get_used_ports())

    game_factory_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        ".opChainDeployments[{0}].disputeGameFactoryProxyAddress".format(l2_num),
    )
    challenger_key = util.read_network_config_value(
        plan,
        deployment_output,
        "challenger-{0}".format(network_params.network_id),
        ".privateKey",
    )

    cmd = [
        "op-challenger",
        "--cannon-l2-genesis="
        + "{0}/genesis-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "--cannon-rollup-config="
        + "{0}/rollup-{1}.json".format(
            ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
            network_params.network_id,
        ),
        "--game-factory-address=" + game_factory_address,
        "--datadir=" + CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--l1-beacon=" + l1_config_env_vars["CL_RPC_URL"],
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--private-key=" + challenger_key,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--trace-type=" + ",".join(challenger_params.cannon_trace_types),
    ]

    # configure files

    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
    }

    # apply customizations

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    if interop_params.enabled:
        cmd.append("--supervisor-rpc=" + interop_constants.SUPERVISOR_ENDPOINT)

    cmd.append(get_prestates_flag(
        prestates_url,
        challenger_params,
    ))

    cmd += challenger_params.extra_params
    cmd = "mkdir -p {0} && {1}".format(
        CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER, " ".join(cmd)
    )

    return ServiceConfig(
        image = image,
        ports = ports,
        entrypoint = ENTRYPOINT_ARGS,
        cmd = [cmd],
        files = files,
        private_ip_address_placeholder = ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )

def get_prestates_flag(prestates_url, challenger_params):
    """Gets the prestates flag

    Args:
        prestates_url (str): The prestate URL.
        challenger_params (dict): The challenger parameters.
    Returns:
        str: The prestates flag.
    """
    if (
        challenger_params.cannon_prestate_path and challenger_params.cannon_prestates_url):
        fail("Only one of cannon_prestate_path and cannon_prestates_url can be set")

    if prestates_url:
        # this takes precedence over cannon_prestate_path and cannon_prestates_url
        return "--cannon-prestates-url=" + prestates_url

    if challenger_params.cannon_prestate_path:
        return "--cannon-prestate=/prestates/prestate-proof.json"

    # we have default for cannon_prestates_url, so it's a safe fallback
    return "--cannon-prestates-url=" + challenger_params.cannon_prestates_url
