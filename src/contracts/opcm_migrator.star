_util = import_module("../util.star")
_artifacts = import_module("./artifacts.star")
_filter = import_module("../util/filter.star")

ethereum_package_genesis_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/prelaunch_data_generator/genesis_constants/genesis_constants.star"
)


def launch(
    plan,
    l1_priv_key,
    deployment_output,
    network_id,
    l1_config_env_vars,
    op_contract_deployer_params,
    migration_params,
):
    # Normalize the L2 artifacts locator
    l2_artifacts_locator = _artifacts.normalize_locator(
        locator=op_contract_deployer_params.l2_artifacts_locator
    )

    # Some of the input for the migrate call are coming from the original deployment output
    # so we'll need to jq them out
    #
    # You can refer to read_chain_cmd function in contract_deployer or read_network_config_value in the challenger launcher
    #
    # FIXME

    proxy_admin_address = _util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .ProxyAdmin'.format(
            _util.to_hex_chain_id(network_id)
        ),
    )
    system_config_proxy_address = _util.read_network_config_value(
        plan,
        deployment_output,
        "state",
        '.opChainDeployments[] | select(.id=="{0}") | .SystemConfigProxy'.format(
            _util.to_hex_chain_id(network_id)
        ),
    )

    # We'll run the OPCM.migrate and collect its output
    opcm_migrate = plan.run_sh(
        name="op-deployer-opcm-migrate",
        description="Run OPCM.migrate",
        image=op_contract_deployer_params.image,
        files={
            # We need to supply the original op-deployer deployment output since we'll need some of the addresses
            "/op-deployer/data": deployment_output,
            "/op-deployer/cache": Directory(persistent_key="cachedir"),
        },
        store=[
            # We will be piping the output of the migration into a json file so we'll store that file
            StoreSpec(src="/op-deployer/opcm.migrate.json"),
        ],
        env_vars={
            # We supply the command args as env variables (just because we can use a nice dict instead of string interpolation)
            "DEPLOYER_CACHE_DIR": "/op-deployer/cache",
            "DEPLOYER_PRIVATE_KEY": l1_priv_key,
            "DEPLOYER_ARTIFACTS_LOCATOR": l2_artifacts_locator,
            "DEPLOYER_OPCM_IMPL_ADDRESS": "FIXME",  # Coming from the deployment output
            "DEPLOYER_PERMISSIONED": migration_params.permissionless,  # This is a bit of a mindfuck since the flag in the go code is called permissionless but the env variable is permissioned
            "DEPLOYER_STARTING_ANCHOR_ROOT": migration_params.starting_anchor_root,
            "DEPLOYER_STARTING_ANCHOR_L2_SEQUENCE_NUMBER": migration_params.starting_anchor_l2_sequence_number,
            "DEPLOYER_PROPOSER_ADDRESS": "FIXME",  # Coming from the deployment output
            "DEPLOYER_CHALLENGER_ADDRESS": "FIXME",  # Coming from the deployment output
            "DEPLOYER_DISPUTE_MAX_GAME_DEPTH": migration_params.dispute_max_game_depth,
            "DEPLOYER_DISPUTE_SPLIT_DEPTH": migration_params.dispute_split_depth,
            "DEPLOYER_DISPUTE_MAX_CLOCK_DURATION": migration_params.dispute_max_clock_duration,
            "DEPLOYER_DISPUTE_CLOCK_EXTENSION": migration_params.dispute_clock_extension,
            "DEPLOYER_DISPUTE_ABSOLUTE_PRESTATE": migration_params.dispute_absolute_prestate,
            "DEPLOYER_INITIAL_BOND": migration_params.initial_bond,
            "DEPLOYER_SYSTEM_CONFIG_PROXY_ADDRESS": system_config_proxy_address,
            "DEPLOYER_OP_CHAIN_PROXY_ADMIN_ADDRESS": proxy_admin_address,
            "L1_RPC_URL": l1_config_env_vars["L1_RPC_URL"],
        },
        run="op-deployer manage migrate > /op-deployer/output.json",
    )

    # Now we have to update the deployment output with the migration output
    # since the migration has redeployed the dispute game factory
    #
    # For this we again jq the dispute game factory address out of the migration output
    # and then we update the deployment output with it. We then return the updated deployment output
    # as the output of this function.
    #
    # This is done using the store=[] argument for the plan.run_sh function
    #
    # FIXME
