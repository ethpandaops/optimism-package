ENVRC_PATH = "/workspace/optimism/.envrc"
FACTORY_DEPLOYER_ADDRESS = "0x3fAB184622Dc19b6109349B94811493BF2a45362"
FACTORY_ADDRESS = "0x4e59b44847b379578588920cA78FbF26c0B4956C"
# raw tx data for deploying Create2Factory contract to L1
FACTORY_DEPLOYER_CODE = "0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"

FUND_SCRIPT_FILEPATH = "../../static_files/scripts"

utils = import_module("../util.star")


def deploy_contracts(
    plan,
    priv_key,
    l1_config_env_vars,
    optimism_args,
):
    l2_chain_ids = ",".join(
        [str(chain.network_params.network_id) for chain in optimism_args.chains]
    )

    op_deployer_init = plan.run_sh(
        name="op-deployer-init",
        description="Initialize L2 contract deployments",
        image=optimism_args.op_contract_deployer_params.image,
        env_vars=l1_config_env_vars,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        run=" && ".join(
            [
                "mkdir -p /network-data",
                "op-deployer init --l1-chain-id $L1_CHAIN_ID --l2-chain-ids {0} --workdir /network-data".format(
                    l2_chain_ids
                ),
            ]
        ),
    )

    hardfork_schedule = []
    for index, chain in enumerate(optimism_args.chains):
        np = chain.network_params

        # rename each hardfork to the name the override expects
        renames = (
            ("l2GenesisFjordTimeOffset", np.fjord_time_offset),
            ("l2GenesisGraniteTimeOffset", np.granite_time_offset),
            ("l2GenesisHoloceneTimeOffset", np.holocene_time_offset),
            ("l2GenesisIsthmusTimeOffset", np.isthmus_time_offset),
            ("l2GenesisInteropTimeOffset", np.interop_time_offset),
        )

        # only include the hardforks that have been activated since
        # toml does not support null values
        for fork_key, activation_timestamp in renames:
            if activation_timestamp != None:
                hardfork_schedule.append((index, fork_key, activation_timestamp))

    intent_updates = (
        [
            (
                "string",
                "l1ContractsLocator",
                optimism_args.op_contract_deployer_params.l1_artifacts_locator,
            ),
            (
                "string",
                "l2ContractsLocator",
                optimism_args.op_contract_deployer_params.l2_artifacts_locator,
            ),
        ]
        + [
            (
                "int",
                "chains.[{0}].deployOverrides.l2BlockTime".format(index),
                str(chain.network_params.seconds_per_slot),
            )
            for index, chain in enumerate(optimism_args.chains)
        ]
        + [
            (
                "bool",
                "chains.[{0}].deployOverrides.fundDevAccounts".format(index),
                "true" if chain.network_params.fund_dev_accounts else "false",
            )
            for index, chain in enumerate(optimism_args.chains)
        ]
        + [
            (
                "string",
                "chains.[{0}].deployOverrides.{1}".format(index, fork_key),
                "0x%x" % activation_timestamp,
            )
            for index, fork_key, activation_timestamp in hardfork_schedule
        ]
    )

    op_deployer_configure = plan.run_sh(
        name="op-deployer-configure",
        description="Configure L2 contract deployments",
        image=utils.DEPLOYMENT_UTILS_IMAGE,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        files={
            "/network-data": op_deployer_init.files_artifacts[0],
        },
        run=" && ".join(
            [
                "cat /network-data/intent.toml | dasel put -r toml -t {0} -v '{2}' '{1}' -o /network-data/intent.toml".format(
                    t, k, v
                )
                for t, k, v in intent_updates
            ]
        ),
    )

    apply_cmds = [
        "op-deployer apply --l1-rpc-url $L1_RPC_URL --private-key $PRIVATE_KEY --workdir /network-data",
    ]
    for chain in optimism_args.chains:
        network_id = chain.network_params.network_id
        apply_cmds.extend(
            [
                "op-deployer inspect genesis --workdir /network-data --outfile /network-data/genesis-{0}.json {0}".format(
                    network_id
                ),
                "op-deployer inspect rollup --workdir /network-data --outfile /network-data/rollup-{0}.json {0}".format(
                    network_id
                ),
            ]
        )

    op_deployer_apply = plan.run_sh(
        name="op-deployer-apply",
        description="Apply L2 contract deployments",
        image=optimism_args.op_contract_deployer_params.image,
        env_vars={"PRIVATE_KEY": str(priv_key)} | l1_config_env_vars,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        files={
            "/network-data": op_deployer_configure.files_artifacts[0],
        },
        run=" && ".join(apply_cmds),
    )

    fund_script_artifact = plan.upload_files(
        src=FUND_SCRIPT_FILEPATH,
        name="op-deployer-fund-script",
    )

    collect_fund = plan.run_sh(
        name="op-deployer-fund",
        description="Collect keys, and fund addresses",
        image=utils.DEPLOYMENT_UTILS_IMAGE,
        env_vars={"PRIVATE_KEY": str(priv_key), "FUND_VALUE": "10ether"}
        | l1_config_env_vars,
        store=[
            StoreSpec(
                src="/network-data",
                name="op-deployer-configs",
            )
        ],
        files={
            "/network-data": op_deployer_apply.files_artifacts[0],
            "/fund-script": fund_script_artifact,
        },
        run='bash /fund-script/fund.sh "{0}"'.format(l2_chain_ids),
    )

    return collect_fund.files_artifacts[0]
