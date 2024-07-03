def wait_for_sync(plan, l1_config_env_vars):
    plan.run_sh(
        name="wait-for-l1-sync",
        description="Wait for L1 to sync up to network",
        env_vars=l1_config_env_vars,
        run="while true; do sleep 3; echo 'Node is syncing, not yet up to head...'; current_head=$(curl -s $CL_RPC_URL/eth/v1/node/syncing | jq -r '.data.head_slot'); sync_distance=$(curl -s $CL_RPC_URL/eth/v1/node/syncing | jq -r '.data.sync_distance'); is_optimistic=$(curl -s $CL_RPC_URL/eth/v1/node/syncing | jq -r '.data.is_optimistic'); echo \"Current head is $current_head and sync distance is $sync_distance\"; if [ \"$is_optimistic\" == \"false\" ]; then echo 'Node is synced!'; break; fi; done",
        wait="72h",
    )
