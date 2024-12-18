DEPLOYMENT_UTILS_IMAGE = "mslipper/deployment-utils:latest"


def read_network_config_value(plan, network_config_file, json_file, json_path):
    mounts = {"/network-data": network_config_file}
    return read_json_value(
        plan, "/network-data/{0}.json".format(json_file), json_path, mounts
    )

def read_json_value(plan, json_file, json_path, mounts=None):
    run = plan.run_sh(
        description="Read JSON value",
        image=DEPLOYMENT_UTILS_IMAGE,
        files=mounts,
        run="cat {0} | jq -j '{1}'".format(json_file, json_path),
    )
    return run.output

def write_to_file(plan, contents, directory, file_name):
    file_path = "{0}/{1}".format(directory, file_name)
    
    run = plan.run_sh(
        description="Write value to a file artifact",
        image=DEPLOYMENT_UTILS_IMAGE,
        store=[file_path],
        run="mkdir -p '{0}' && echo '{2}' > '{1}'".format(directory, file_path, contents),
    )
    
    return run.files_artifacts[0]

def to_hex_chain_id(chain_id):
    out = "%x" % int(chain_id)
    pad = 64 - len(out)
    return "0x" + "0" * pad + out
