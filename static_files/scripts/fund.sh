#!/usr/bin/env bash

set -euo pipefail

export ETH_RPC_URL="$L1_RPC_URL"

addr=$(cast wallet address "$PRIVATE_KEY")
nonce=$(cast nonce "$addr")
mnemonic="test test test test test test test test test test test junk"
roles=("proposer" "batcher" "sequencer" "challenger" "l2ProxyAdmin" "l1ProxyAdmin" "baseFeeVaultRecipient" "l1FeeVaultRecipient" "sequencerFeeVaultRecipient" "systemConfigOwner")

IFS=',';read -r -a chain_ids <<< "$1"

write_keyfile() {
  echo "{\"address\":\"$1\",\"privateKey\":\"$2\"}" > "/network-data/$3.json"
}

send() {
  cast send $1 --value "$FUND_VALUE" --private-key "$PRIVATE_KEY" --nonce "$nonce" --async
  nonce=$((nonce+1))
}

# Create a JSON object to store all the wallet addresses and private keys, start with an empty one
wallets_json=$(jq -n '{}')
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

    wallets_json=$(echo "$wallets_json" | jq \
      --arg role "$role" \
      --arg private_key "$private_key" \
      --arg address "$address" \
      '.[$role + "PrivateKey"] = $private_key | .[$role + "Address"] = $address')

  done
  cat "/network-data/genesis-$chain_id.json" | jq --from-file /fund-script/gen2spec.jq > "/network-data/chainspec-$chain_id.json"
done

echo "Wallet private key and addresses"
wallets_json=$(echo "$wallets_json" | jq --arg addr "$addr" --arg private_key "0x$PRIVATE_KEY" '.["l1FaucetPrivateKey"] = $private_key | .["l1FaucetAddress"] = $addr')
wallets_json=$(echo "$wallets_json" | jq --arg addr "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" --arg private_key  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" '.["l2FaucetPrivateKey"] = $private_key | .["l2FaucetAddress"] = $addr')
echo "$wallets_json" > "/network-data/wallets.json"
echo "$wallets_json"
