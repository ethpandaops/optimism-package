ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

input_parser = import_module("../../package_io/input_parser.star")
observability = import_module("../../observability/observability.star")
op_signer_launcher = import_module("../../signer/op_signer_launcher.star")

interop_constants = import_module("../../interop/constants.star")
util = import_module("../../util.star")

#
#  ---------------------------------- Challenger client -------------------------------------
SERVICE_TYPE = "challenger"
SERVICE_NAME = util.make_op_service_name(SERVICE_TYPE)

DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/{0}/{0}-data".format(SERVICE_NAME)
ENTRYPOINT_ARGS = ["sh", "-c"]


def get_used_ports():
    used_ports = {}
    return used_ports


def launch(
    plan,
    el_context,
    cl_context,
    l1_config_env_vars,
    signer_service,
    signer_client,
    game_factory_address,
    deployment_output,
    network_params,
    challenger_params,
    interop_params,
    observability_helper,
):
    service_instance_name = util.make_service_instance_name(SERVICE_NAME, network_params)

    cannon_prestate_artifact = None
    if challenger_params.cannon_prestate_path:
        cannon_prestate_artifact = plan.upload_files(
            src=challenger_params.cannon_prestate_path,
            name="{}-prestates".format(service_instance_name),
        )

    service = plan.add_service(service_instance_name, make_service_config(
        plan,
        cannon_prestate_artifact,
        el_context,
        cl_context,
        l1_config_env_vars,
        signer_service,
        signer_client,
        game_factory_address,
        deployment_output,
        network_params,
        challenger_params,
        interop_params,
        observability_helper,
    ))

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service


def make_service_config(
    plan,
    cannon_prestate_artifact,
    el_context,
    cl_context,
    l1_config_env_vars,
    signer_service,
    signer_client,
    game_factory_address,
    deployment_output,
    network_params,
    challenger_params,
    interop_params,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = [
        SERVICE_NAME,
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
        "--datadir=" + DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--l1-beacon=" + l1_config_env_vars["CL_RPC_URL"],
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--private-key=" + signer_client.key,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--trace-type=" + ",".join(challenger_params.cannon_trace_types),
    ]

    # configure files

    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
    }

    # apply customizations

    op_signer_launcher.configure_op_signer(cmd, files, signer_service, signer_client)

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)

    if interop_params.enabled:
        cmd.append("--supervisor-rpc=" + interop_constants.SUPERVISOR_ENDPOINT)
        # TraceTypeSupper{Cannon|Permissioned} needs --cannon-depset-config to be set
        # Added at https://github.com/ethereum-optimism/optimism/pull/14666
        # Temporary fix: Add a dummy flag
        # Tracked at issue https://github.com/ethpandaops/optimism-package/issues/189
        cmd.append("--cannon-depset-config=dummy-file.json")

    if (
        challenger_params.cannon_prestate_path
        and challenger_params.cannon_prestates_url
    ):
        fail("Only one of cannon_prestate_path and cannon_prestates_url can be set")
    elif cannon_prestate_artifact != None:
        files["/prestates"] = cannon_prestate_artifact
        cmd.append("--cannon-prestate=/prestates/prestate-proof.json")
    elif challenger_params.cannon_prestates_url:
        cmd.append("--cannon-prestates-url=" + challenger_params.cannon_prestates_url)
    else:
        fail("One of cannon_prestate_path or cannon_prestates_url must be set")

    cmd += challenger_params.extra_params
    cmd = "mkdir -p {0} && {1}".format(
        DATA_DIRPATH_ON_SERVICE_CONTAINER, " ".join(cmd)
    )

    # legacy default image logic
    image = (
        challenger_params.image
        if challenger_params.image != ""
        else input_parser.DEFAULT_CHALLENGER_IMAGES[SERVICE_NAME]
    )

    return ServiceConfig(
        image=image,
        ports=ports,
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[cmd],
        files=files,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
