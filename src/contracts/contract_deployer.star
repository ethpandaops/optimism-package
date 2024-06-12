IMAGE = "ethpandaops/optimism-contract-deployer:latest"

ENVRC_PATH = "/workspace/optimism/.envrc"

FACTORY_DEPLOYER_ADDRESS = "0x3fAB184622Dc19b6109349B94811493BF2a45362"
FACTORY_DEPLOYER_CODE = "0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"


def launch_contract_deployer(
    plan,
    priv_key,
    l1_config_env_vars,
    l2_config_env_vars,
):
    op_genesis = plan.run_sh(
        name="op_genesis",
        description="Deploying L2 contracts (takes a few minutes (30 mins for mainnet preset - 4 mins for minimal preset) -- L1 has to be finalized first)",
        image=IMAGE,
        env_vars={
            "WEB3_PRIVATE_KEY": str(priv_key),
            "FUND_VALUE": "10",
            "DEPLOY_CONFIG_PATH": "/workspace/optimism/packages/contracts-bedrock/deploy-config/getting-started.json",
            "DEPLOYMENT_CONTEXT": "getting-started",
        }
        | l1_config_env_vars
        | l2_config_env_vars,
        store=[
            StoreSpec(src="/network-configs", name="op-genesis-configs"),
        ],
        run=" && ".join(
            [
                "./packages/contracts-bedrock/scripts/getting-started/wallets.sh >> {0}".format(
                    ENVRC_PATH
                ),
                "sed -i '1d' {0}".format(
                    ENVRC_PATH
                ),  # Remove the first line (not commented out)
                "echo 'export IMPL_SALT=$(openssl rand -hex 32)' >> {0}".format(
                    ENVRC_PATH
                ),
                ". {0}".format(ENVRC_PATH),
                "mkdir -p /network-configs",
                "web3 transfer $FUND_VALUE to $GS_ADMIN_ADDRESS",  # Fund Admin
                "sleep 3",
                "web3 transfer $FUND_VALUE to $GS_BATCHER_ADDRESS",  # Fund Batcher
                "sleep 3",
                "web3 transfer $FUND_VALUE to $GS_PROPOSER_ADDRESS",  # Fund Proposer
                "sleep 3",
                "web3 transfer $FUND_VALUE to {0}".format(
                    FACTORY_DEPLOYER_ADDRESS
                ),  # Fund Factory deployer
                "sleep 3",
                # sleep till chain is finalized
                "while true; do sleep 3; echo 'Chain is not yet finalized...'; if [ \"$(curl -s $CL_RPC_URL/eth/v1/beacon/states/head/finality_checkpoints | jq -r '.data.finalized.epoch')\" != \"0\" ]; then echo 'Chain is finalized!'; break; fi; done",
                "cd /workspace/optimism/packages/contracts-bedrock",
                "./scripts/getting-started/config.sh",
                "cast publish --rpc-url $L1_RPC_URL {0}".format(FACTORY_DEPLOYER_CODE),
                "sleep 12",
                "forge script scripts/Deploy.s.sol:Deploy --private-key $GS_ADMIN_PRIVATE_KEY --broadcast --rpc-url $L1_RPC_URL",
                "sleep 3",
                "CONTRACT_ADDRESSES_PATH=$DEPLOYMENT_OUTFILE forge script scripts/L2Genesis.s.sol:L2Genesis --sig 'runWithStateDump()' --chain-id $L2_CHAIN_ID",
                "cd /workspace/optimism/op-node/bin",
                "./op-node genesis l2 \
                    --l1-rpc $L1_RPC_URL \
                    --deploy-config $DEPLOY_CONFIG_PATH \
                    --l2-allocs $STATE_DUMP_PATH \
                    --l1-deployments $DEPLOYMENT_OUTFILE \
                    --outfile.l2 /network-configs/genesis.json \
                    --outfile.rollup /network-configs/rollup.json",
                "mv $DEPLOY_CONFIG_PATH /network-configs/getting-started.json",
                "mv $DEPLOYMENT_OUTFILE /network-configs/kurtosis.json",
                "mv $STATE_DUMP_PATH /network-configs/state-dump.json",
                "echo -n $GS_SEQUENCER_PRIVATE_KEY > /network-configs/GS_SEQUENCER_PRIVATE_KEY",
                "echo -n $GS_BATCHER_PRIVATE_KEY > /network-configs/GS_BATCHER_PRIVATE_KEY",
                "echo -n $GS_PROPOSER_PRIVATE_KEY > /network-configs/GS_PROPOSER_PRIVATE_KEY",
            ]
        ),
        wait="2000s",
    )

    gs_sequencer_private_key = plan.run_sh(
        name="read_sequencer_private_key",
        description="Getting the sequencer private key",
        run="cat /network-configs/GS_SEQUENCER_PRIVATE_KEY ",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    gs_batcher_private_key = plan.run_sh(
        name="read_batcher_private_key",
        description="Getting the batcher private key",
        run="cat /network-configs/GS_BATCHER_PRIVATE_KEY ",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    gs_proposer_private_key = plan.run_sh(
        name="read_proposer_private_key",
        description="Getting the proposer private key",
        run="cat /network-configs/GS_PROPOSER_PRIVATE_KEY ",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    l2oo_address = plan.run_sh(
        name="read_l2oo_address",
        description="Getting the L2OutputOracleProxy address",
        run="jq -r .L2OutputOracleProxy /network-configs/kurtosis.json | tr -d '\n'",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    l1_bridge_address = plan.run_sh(
        name="read_l1_bridge_address",
        description="Getting the L1StandardBridgeProxy address",
        run="jq -r .L1StandardBridgeProxy /network-configs/kurtosis.json | tr -d '\n'",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    l1_deposit_start_block = plan.run_sh(
        name="read_l1_deposit_start_block",
        description="Getting the L1StandardBridgeProxy address",
        image="badouralix/curl-jq",
        run="jq -r .genesis.l1.number  /network-configs/rollup.json | tr -d '\n'",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    l1_portal_contract = plan.run_sh(
        name="read_l1_portal_contract",
        description="Getting the L1 portal contract",
        run="jq -r .OptimismPortal  /network-configs/kurtosis.json | tr -d '\n'",
        files={"/network-configs": op_genesis.files_artifacts[0]},
    )

    private_keys = {
        "GS_SEQUENCER_PRIVATE_KEY": gs_sequencer_private_key.output,
        "GS_BATCHER_PRIVATE_KEY": gs_batcher_private_key.output,
        "GS_PROPOSER_PRIVATE_KEY": gs_proposer_private_key.output,
    }

    blockscout_env_variables = {
        "INDEXER_OPTIMISM_L1_PORTAL_CONTRACT": l1_portal_contract.output,
        "INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK": l1_deposit_start_block.output,
        "INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK": l1_deposit_start_block.output,
        "INDEXER_OPTIMISM_L1_BATCH_START_BLOCK": l1_deposit_start_block.output,
        "INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT": l2oo_address.output,
    }

    return (
        op_genesis.files_artifacts[0],
        private_keys,
        l2oo_address.output,
        l1_bridge_address.output,
        blockscout_env_variables,
    )
