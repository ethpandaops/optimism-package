#!/usr/bin/env bash

set -euxo pipefail

export ETH_RPC_URL="$L1_RPC_URL"

addr=$(cast wallet address "$PRIVATE_KEY")
nonce=$(cast nonce "$addr")
mnemonic="test test test test test test test test test test test junk"

IFS=',';read -r -a chain_ids <<< "$1"

write_keyfile() {
  echo "{\"address\":\"$1\",\"privateKey\":\"$2\"}" > "/network-data/$3.json"
}

send() {
  cast send $1 --value "$FUND_VALUE" --private-key "$PRIVATE_KEY" --nonce "$nonce" --async
  nonce=$((nonce+1))
}

for chain_id in "${chain_ids[@]}"; do
  proposer_priv=$(cast wallet private-key "$mnemonic" "m/44'/60'/2'/$chain_id/1")
  proposer_addr=$(cast wallet address "$proposer_priv")
  write_keyfile "$proposer_addr" "$proposer_priv" "proposer-$chain_id"
  batcher_priv=$(cast wallet private-key "$mnemonic" "m/44'/60'/2'/$chain_id/2")
  batcher_addr=$(cast wallet address "$batcher_priv")
  write_keyfile "$batcher_addr" "$batcher_priv" "batcher-$chain_id"
  sequencer_priv=$(cast wallet private-key "$mnemonic" "m/44'/60'/2'/$chain_id/3")
  sequencer_addr=$(cast wallet address "$sequencer_priv")
  write_keyfile "$sequencer_addr" "$sequencer_priv" "sequencer-$chain_id"
  challenger_priv=$(cast wallet private-key "$mnemonic" "m/44'/60'/2'/$chain_id/4")
  challenger_addr=$(cast wallet address "$challenger_priv")
  write_keyfile "$challenger_addr" "$challenger_priv" "challenger-$chain_id"
  send "$proposer_addr"
  send "$batcher_addr"
  send "$challenger_addr"

  cat "/network-data/genesis-$chain_id.json" | jq --from-file /fund-script/gen2spec.jq > "/network-data/chainspec-$chain_id.json"
done