def read_network_config_value(plan, network_config_file, json_file, json_path):
    mounts = {"/network-data": network_config_file}
    return read_json_value(plan, "/network-data/{0}.json".format(json_file), json_path, mounts)

def read_json_value(plan, json_file, json_path, mounts=None):
    run = plan.run_sh(
        name="read-json-value",
        description="Read JSON value",
        image="ethereumoptimism/foundry-minimal:latest",
        files=mounts,
        run="cat {0} | jq -j '{1}'".format(json_file, json_path),
    )
    return run.output

def to_hex_chain_id(chain_id):
    out = "%x" % int(chain_id)
    pad = 64-len(out)
    return "0x" + "0"*pad + out