# The min/max CPU/memory that mev-flood can use
MIN_CPU = 100
MAX_CPU = 2000
MIN_MEMORY = 128
MAX_MEMORY = 1024

IMAGE = "bbusa/op:latest"

ENVRC_PATH = "/workspace/optimism/.envrc"

FACTORY_DEPLOYER_ADDRESS = "0x3fAB184622Dc19b6109349B94811493BF2a45362"
FACTORY_DEPLOYER_CODE = "0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222"
def launch_contract_deployer(
    plan,
    el_rpc_http_url,
    cl_rpc_http_url,
    priv_key,
):
    plan.run_sh(
        description="Deploying L2 contracts (takes a few minutes (30 mins for mainnet preset - 4 mins for minimal preset) -- L1 has to be finalized first)",
        image=IMAGE,
        env_vars={
            "WEB3_RPC_URL": str(el_rpc_http_url),
            "WEB3_PRIVATE_KEY": str(priv_key),
            "CL_RPC_URL": str(cl_rpc_http_url),
            "FUND_VALUE": "10",
        },
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
                "echo 'export L1_RPC_KIND=any' >> {0}".format(ENVRC_PATH),
                "echo 'export L1_RPC_URL={0}' >> {1}".format(
                    el_rpc_http_url, ENVRC_PATH
                ),
                "echo 'export IMPL_SALT=$(openssl rand -hex 32)' >> {0}".format(
                    ENVRC_PATH
                ),
                "echo 'export DEPLOYMENT_CONTEXT=getting-started' >> {0}".format(
                    ENVRC_PATH
                ),
                ". {0}".format(ENVRC_PATH),
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
                "cast publish --rpc-url $WEB3_RPC_URL {0}".format(FACTORY_DEPLOYER_CODE),
                "sleep 12",
                "forge script scripts/Deploy.s.sol:Deploy --private-key $GS_ADMIN_PRIVATE_KEY --broadcast --rpc-url $L1_RPC_URL",
                "sleep 3",
                "cd /workspace/optimism/op-node",
                "go run cmd/main.go genesis l2 --deploy-config ../packages/contracts-bedrock/deploy-config/getting-started.json --l1-deployments ../packages/contracts-bedrock/deployments/getting-started/.deploy --outfile.l2 genesis.json --outfile.rollup rollup.json --l1-rpc $L1_RPC_URL",
                "mkdir -p /network-configs",
                "mv /workspace/optimism/op-node/genesis.json /network-configs/genesis.json",
                "mv /workspace/optimism/op-node/rollup.json /network-configs/rollup.json",
                "mv /workspace/optimism/packages/contracts-bedrock/deployments/getting-started/.deploy /network-configs/.deploy",
            ]
        ),
        wait = "2000s",
    )
