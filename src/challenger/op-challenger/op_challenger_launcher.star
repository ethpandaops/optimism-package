ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

#
#  ---------------------------------- Challenger client -------------------------------------
CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-challenger/op-challenger-data"
ENTRYPOINT_ARGS = ["sh", "-c"]


def get_used_ports():
    used_ports = {}
    return used_ports


def launch(
    plan,
    service_name,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    gs_challenger_private_key,
    game_factory_address,
    deployment_output,
    network_params,
    challenger_params,
):
    challenger_service_name = "{0}".format(service_name)

    config = get_challenger_config(
        plan,
        service_name,
        image,
        el_context,
        cl_context,
        l1_config_env_vars,
        gs_challenger_private_key,
        game_factory_address,
        deployment_output,
        network_params,
        challenger_params,
    )

    challenger_service = plan.add_service(service_name, config)

    return "op_challenger"


def get_challenger_config(
    plan,
    service_name,
    image,
    el_context,
    cl_context,
    l1_config_env_vars,
    gs_challenger_private_key,
    game_factory_address,
    deployment_output,
    network_params,
    challenger_params,
):
    cmd = [
        "op-challenger",
        "--cannon-l2-genesis="
        + ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/genesis-{0}.json".format(network_params.network_id),
        "--cannon-rollup-config="
        + ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
        + "/rollup-{0}.json".format(network_params.network_id),
        "--game-factory-address=" + game_factory_address,
        "--datadir=" + CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER,
        "--l1-beacon=" + l1_config_env_vars["CL_RPC_URL"],
        "--l1-eth-rpc=" + l1_config_env_vars["L1_RPC_URL"],
        "--l2-eth-rpc=" + el_context.rpc_http_url,
        "--private-key=" + gs_challenger_private_key,
        "--rollup-rpc=" + cl_context.beacon_http_url,
        "--trace-type=" + "cannon,permissioned",
    ]
    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
    }

    if (
        challenger_params.cannon_prestate_path
        and challenger_params.cannon_prestates_url
    ):
        fail("Only one of cannon_prestate_path and cannon_prestates_url can be set")
    elif challenger_params.cannon_prestate_path:
        cannon_prestate_artifact = plan.upload_files(
            src=challenger_params.cannon_prestate_path,
            name="{}-prestates".format(service_name),
        )
        files["/prestates"] = cannon_prestate_artifact
        cmd.append("--cannon-prestate=/prestates/prestate-proof.json")
    elif challenger_params.cannon_prestates_url:
        cmd.append("--cannon-prestates-url=" + challenger_params.cannon_prestates_url)
    else:
        fail("One of cannon_prestate_path or cannon_prestates_url must be set")

    cmd += challenger_params.extra_params
    cmd = "mkdir -p {0} && {1}".format(
        CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER, " ".join(cmd)
    )

    ports = get_used_ports()
    return ServiceConfig(
        image=image,
        ports=ports,
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[cmd],
        files=files,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
