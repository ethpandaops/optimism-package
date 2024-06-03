# The min/max CPU/memory that mev-flood can use
MIN_CPU = 100
MAX_CPU = 2000
MIN_MEMORY = 128
MAX_MEMORY = 1024

IMAGE = "bbusa/op:latest"

ENVRC_PATH = "/workspace/optimism/.envrc"
ENTRYPOINT_ARGS = ["/bin/bash", "-c"]
def launch_contract_deployer(
    plan,
    el_rpc_http_url,
    cl_rpc_http_url,
    priv_key,
):
    plan.add_service(
        name="op-contract-deployer",
        config=ServiceConfig(
            image=IMAGE,
            min_cpu=MIN_CPU,
            max_cpu=MAX_CPU,
            min_memory=MIN_MEMORY,
            max_memory=MAX_MEMORY,
            entrypoint=ENTRYPOINT_ARGS,
            env_vars = {
                "WEB3_RPC_URL": str(el_rpc_http_url),
                "WEB3_PRIVATE_KEY": str(priv_key),
                "CL_RPC_URL": str(cl_rpc_http_url),
                "FUND_VALUE": "10",
            },
            cmd=[
                " && ".join(
                    [
                        "./packages/contracts-bedrock/scripts/getting-started/wallets.sh >> {0}".format(ENVRC_PATH),
                        "sed -i '1d' {0}".format(ENVRC_PATH), # Remove the first line (not commented out)
                        "echo 'export L1_RPC_KIND=any' >> {0}".format(ENVRC_PATH),
                        "echo 'export L1_RPC_URL={0}' >> {1}".format(el_rpc_http_url, ENVRC_PATH),
                        "echo 'export IMPL_SALT=$(openssl rand -hex 32)' >> {0}".format(ENVRC_PATH),
                        "echo 'export DEPLOYMENT_CONTEXT=getting-started' >> {0}".format(ENVRC_PATH),
                        "source {0}".format(ENVRC_PATH),
                        "web3 transfer $FUND_VALUE to $GS_ADMIN_ADDRESS", # Fund Admin
                        "sleep 3",
                        "web3 transfer $FUND_VALUE to $GS_BATCHER_ADDRESS", # Fund Batcher
                        "sleep 3",
                        "web3 transfer $FUND_VALUE to $GS_PROPOSER_ADDRESS", # Fund Proposer
                        "sleep 3",
                        # sleep till chain is finalized
                        "while true; do sleep 3; echo 'Chain is not yet finalized...'; if [ $(curl -s $CL_RPC_URL/eth/v1/beacon/states/1/finality_checkpoints | jq '.finalized') = true ]; then echo 'Chain is finalized!'; break; fi; done",
                        "cd /workspace/optimism/packages/contracts-bedrock",
                        "./scripts/getting-started/config.sh",
                        "cd /workspace/optimism",
                        "sleep 3",
                        # "cast codesize 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url $WEB3_RPC_URL",
                        # "web3 transfer $FUND_VALUE to 0x3fAB184622Dc19b6109349B94811493BF2a45362", # Fund Factory deployer

                        # "sleep 12",
                        # "cast publish --rpc-url $WEB3_RPC_URL 0xf8a58085174876e800830186a08080b853604580600e600039806000f350fe7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf31ba02222222222222222222222222222222222222222222222222222222222222222a02222222222222222222222222222222222222222222222222222222222222222",
                        "sleep 100000",
                    ]
                )
            ],
        ),
    )

