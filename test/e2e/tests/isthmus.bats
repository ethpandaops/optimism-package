setup() {
    load "../lib/bats-support/load.bash"
    load "../lib/bats-assert/load.bash"
}

@test "should have isthmus time if isthmus_time_offset is configured" {
    local ENCLAVE_ID=op-isthmus--001

    # First we start the enclave
    run kurtosis run --enclave $ENCLAVE_ID . --args-file test/e2e/tests/assets/kurtosis_args_isthmus.yaml
    assert_success

    # We get the UUID of the op-geth service
    local OP_GETH_SERVICE_UUID=$(kurtosis enclave inspect $ENCLAVE_ID --full-uuids| grep op-el-1-op-geth-op-node-op-kurtosis | awk '{print $1;}')
    assert [ -n "$OP_GETH_SERVICE_UUID" ]

    # Now we find its RPC URL
    local OP_GETH_RPC_URL=$(kurtosis service inspect $ENCLAVE_ID $OP_GETH_SERVICE_UUID | grep ' rpc:' | awk '{print $4;}')
    assert [ -n "$OP_GETH_RPC_URL" ]

    # We ask the RPC for the node info
    local OP_GETH_NODE_INFO_JSON=$(curl -s -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}' $OP_GETH_RPC_URL)

    # And finally we find the isthmusTime and make sure it's defined
    local OP_GETH_ISTHMUS_TIME=$(jq '.result.protocols.eth.config.isthmusTime' <<< $OP_GETH_NODE_INFO_JSON)
    assert_equal "$OP_GETH_ISTHMUS_TIME" "0"

    kurtosis enclave rm -f $ENCLAVE_ID
}