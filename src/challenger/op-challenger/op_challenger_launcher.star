ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

observability = import_module("../../observability/observability.star")
prometheus = import_module("../../observability/prometheus/prometheus_launcher.star")

constants = import_module("../../package_io/constants.star")
interop_constants = import_module("../../interop/constants.star")
util = import_module("../../util.star")

#
#  ---------------------------------- Challenger client -------------------------------------
CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER = "/data/op-challenger/op-challenger-data"
ENTRYPOINT_ARGS = ["sh", "-c"]


def launch(
    plan,
    name,
    params,
    l1_config_env_vars,
    l2s,
    deployment_output,
    observability_helper,
):
    # First we filter out the L2s we are interested in
    challenger_l2s = [l2 for l2 in l2s if l2.network_id in params.participants]

    service_name = "op-challenger-{0}".format(name)
    config = get_challenger_config(
        plan=plan,
        params=params,
        service_name=service_name,
        l1_config_env_vars=l1_config_env_vars,
        l2s=challenger_l2s,
        deployment_output=deployment_output,
        observability_helper=observability_helper,
    )

    service = plan.add_service(service_name, config)

    if observability_helper.enabled:
        for l2 in challenger_l2s:
            observability.register_op_service_metrics_job(
                observability_helper, service, l2.name
            )

    return struct(
        service=service,
        networks=challenger_l2s,
    )


def get_challenger_config(
    plan,
    params,
    service_name,
    l1_config_env_vars,
    l2s,
    deployment_output,
    observability_helper,
):
    # FIXME Challenger is now taking the first network value as the source of truth for
    # both the contract addresses and the private keys
    #
    # The challenger configuration should be adjusted so that its participant networks can only come from the same interop set,
    # in which case the values for all the networks should be identical
    first_l2 = l2s[0]
    game_factory_address = util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .l1StandardBridgeProxyAddress'.format(
            first_l2.network_id
        ),
    )
    challenger_key = util.read_network_config_value(
        plan,
        deployment_output,
        "challenger-{0}".format(first_l2.network_id),
        ".privateKey",
    )

    cmd = [
        "op-challenger",
        "--cannon-l2-genesis={}".format(
            ",".join(
                [
                    "{0}/genesis-{1}.json".format(
                        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
                        l2.network_id,
                    )
                    for l2 in l2s
                ]
            )
        ),
        "--cannon-rollup-config={}".format(
            ",".join(
                [
                    "{0}/rollup-{1}.json".format(
                        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS,
                        l2.network_id,
                    )
                    for l2 in l2s
                ]
            )
        ),
        "--game-factory-address=" + game_factory_address,
        "--datadir={}".format(CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER),
        "--l1-beacon={}".format(l1_config_env_vars["CL_RPC_URL"]),
        "--l1-eth-rpc={}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l2-eth-rpc={}".format(
            ",".join(
                [
                    ",".join([p.el_context.rpc_http_url for p in l2.participants])
                    for l2 in l2s
                ]
            )
        ),
        "--private-key={}".format(challenger_key),
        "--rollup-rpc={}".format(
            ",".join(
                [
                    ",".join([p.cl_context.beacon_http_url for p in l2.participants])
                    for l2 in l2s
                ]
            )
        ),
        "--trace-type={}".format(",".join(params.cannon_trace_types)),
    ]

    # configure files

    files = {
        ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
    }

    if params.cannon_prestate_path:
        cannon_prestate_artifact = plan.upload_files(
            src=params.cannon_prestate_path,
            name="{}-prestates".format(service_name),
        )
        files["/prestates"] = cannon_prestate_artifact
        cmd.append("--cannon-prestate=/prestates/prestate-proof.json")
    elif params.cannon_prestates_url:
        cmd.append("--cannon-prestates-url=" + params.cannon_prestates_url)
    else:
        fail("One of cannon_prestate_path or cannon_prestates_url must be set")

    cmd += params.extra_params
    
    ports = {}
    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)
    
    cmd = "mkdir -p {0} && {1}".format(
        CHALLENGER_DATA_DIRPATH_ON_SERVICE_CONTAINER, " ".join(cmd)
    )

    return ServiceConfig(
        image=params.image,
        entrypoint=ENTRYPOINT_ARGS,
        cmd=[cmd],
        files=files,
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        ports=ports,
    )
