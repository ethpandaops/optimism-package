#!/usr/bin/env bash

set -euo pipefail

export ETH_RPC_URL="$L1_RPC_URL"

addr=$(cast wallet address "$PRIVATE_KEY")
nonce=$(cast nonce "$addr")
mnemonic="test test test test test test test test test test test junk"
roles=("proposer" "batcher" "sequencer" "challenger" "L2ProxyAdmin" "L1ProxyAdmin" "BaseFeeVaultRecipient" "L1FeeVaultRecipient" "SequencerFeeVaultRecipient" "SystemConfigOwner")

IFS=',';read -r -a chain_ids <<< "$1"

write_keyfile() {
  echo "{\"address\":\"$1\",\"privateKey\":\"$2\"}" > "/network-data/$3.json"
}

send() {
  cast send $1 --value "$FUND_VALUE" --private-key "$PRIVATE_KEY" --nonce "$nonce" --async
  nonce=$((nonce+1))
}

for chain_id in "${chain_ids[@]}"; do
  for index in "${!roles[@]}"; do
    role="${roles[$index]}"
    role_idx=$((index+1))

    # Skip wallet addrs for anything other Proposer/Batcher/Sequencer/Challenger if not on local L1
    if [[ "${L1_NETWORK}" != "local" && $role_idx -gt 4 ]]; then
      continue
    fi

    private_key=$(cast wallet private-key "$mnemonic" "m/44'/60'/2'/$chain_id/$role_idx")
    address=$(cast wallet address "${private_key}")
    write_keyfile "${address}" "${private_key}" "${role}-$chain_id"
    send "${address}"

    echo "${role} on chain $chain_id, private key:"${private_key}", address:"${address}""
  done

  cat "/network-data/genesis-$chain_id.json" | jq --from-file /fund-script/gen2spec.jq > "/network-data/chainspec-$chain_id.json"
done

echo "L1 faucet private key:"0x${PRIVATE_KEY}", address:"${addr}""
echo "L2 faucet private key:"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80", address:"0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266""
