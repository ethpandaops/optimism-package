constants = import_module("./package_io/constants.star")

DEPLOYMENT_UTILS_IMAGE = "mslipper/deployment-utils:latest"

NETWORK_DATA_DIR = "/network-data"


def read_network_config_value(plan, network_config_file, json_file, json_path):
    mounts = {NETWORK_DATA_DIR: network_config_file}
    return read_json_value(
        plan, "{0}/{1}.json".format(NETWORK_DATA_DIR, json_file), json_path, mounts
    )


def read_service_network_config_value(
    plan, network_config_file, service_type, network_params, json_path
):
    return read_network_config_value(
        plan,
        network_config_file,
        "{0}-{1}".format(service_type, network_params.network_id),
        json_path,
    )


def read_service_private_key(plan, network_config_file, service_type, network_params):
    return read_service_network_config_value(
        plan, network_config_file, service_type, network_params, ".privateKey"
    )


def read_json_value(plan, json_file, json_path, mounts=None):
    run = plan.run_sh(
        description="Read JSON value",
        image=DEPLOYMENT_UTILS_IMAGE,
        files=mounts,
        run="jq -j '{1}' < {0}".format(json_file, json_path),
    )
    return run.output


def read_file(plan, file_path, mounts=None):
    run = plan.run_sh(
        description="Read file",
        image=DEPLOYMENT_UTILS_IMAGE,
        files=mounts,
        run="cat {0}".format(file_path),
    )
    return run.output


def write_to_file(plan, contents, directory, file_name):
    file_path = "{0}/{1}".format(directory, file_name)

    run = plan.run_sh(
        description="Write value to a file artifact",
        image=DEPLOYMENT_UTILS_IMAGE,
        store=[
            StoreSpec(src=file_path, name=file_name),
        ],
        run="mkdir -p '{0}' && echo '{2}' > '{1}'".format(
            directory, file_path, contents
        ),
    )

    return run.files_artifacts[0]


def to_hex_chain_id(chain_id):
    out = "%x" % int(chain_id)
    pad = 64 - len(out)
    return "0x" + "0" * pad + out


def label_from_image(image):
    """Generate a label from an image name.

    Truncate the image label to 63 characters max to comply with k8s label length limit.
    The label is expected to be in the format of <registry>/<image>:<tag>.
    But it case it's too long, we take the longest meaningful suffix
    (so that it's still recognizable), breaking at slashes (so that it's valid).

    Args:
        image: The image to label.

    Returns:
        The potentially truncated label.
    """
    max_length = 63
    if len(image) <= max_length:
        return image
    cpts = image.split("/")
    label = cpts[-1]
    for cpt in reversed(cpts[:-1]):
        if len(label) + len(cpt) + 1 > max_length:
            break
        label = cpt + "/" + label
    # just in case the last part is already too long
    if len(label) > max_length:
        label = label[-max_length:]
    return label


def join_cmds(commands):
    return " && ".join(commands)


def make_op_service_name(service_type):
    return "op-{0}".format(service_type)


def make_service_instance_name(service_name, network_params):
    return "{0}-{1}".format(service_name, network_params.network)


def get_service_port_num(service, port_id):
    return service.ports[port_id].number


def get_service_http_port_num(service):
    return get_service_port_num(service, constants.HTTP_PORT_ID)


def make_url_authority(host, port_num):
    return "{0}:{1}".format(host, port_num)


def prefix_url_scheme(scheme, authority):
    return "{0}://{1}".format(scheme, authority)


def prefix_url_scheme_http(authority):
    return prefix_url_scheme("http", authority)


def prefix_url_scheme_https(authority):
    return prefix_url_scheme("https", authority)


def prefix_url_scheme_ws(authority):
    return prefix_url_scheme("ws", authority)


def make_http_url(host, port_num):
    return prefix_url_scheme_http(make_url_authority(host, port_num))


def make_ws_url(host, port_num):
    return prefix_url_scheme_ws(make_url_authority(host, port_num))


def make_service_url_authority(service, port_id):
    return make_url_authority(service.hostname, get_service_port_num(service, port_id))


def make_service_http_url(service, port_id=constants.HTTP_PORT_ID):
    return prefix_url_scheme_http(make_service_url_authority(service, port_id))


def make_service_https_url(service, port_id=constants.HTTP_PORT_ID):
    return prefix_url_scheme_https(make_service_url_authority(service, port_id))


def make_service_ws_url(service, port_id=constants.WS_PORT_ID):
    return prefix_url_scheme_ws(make_service_url_authority(service, port_id))


def make_execution_engine_url(el_context):
    return make_http_url(
        el_context.ip_addr,
        el_context.engine_rpc_port_num,
    )


def make_execution_rpc_url(el_context):
    return make_http_url(
        el_context.ip_addr,
        el_context.rpc_port_num,
    )


def configure_op_service_rpc(cmd, port_num):
    cmd.append("--rpc.addr=0.0.0.0")
    cmd.append("--rpc.port={0}".format(port_num))
    cmd.append("--rpc.enable-admin")

# Removes all None values from a dictionary and returns a new dictionary.
def filter_none(d):
    return {k: v for k, v in d.items() if v != None}

# Returns a list of duplicate items in the input list.
def get_duplicates(items):
    # Unfortunately kurotis star doesn't support sets so we'll have to do with O(N^2) complexity and a list
    # 
    # The redeeming factor is the fact that we are dealing with very limited list sizes
    seen = []
    duplicates = []
    for item in items:
        if item in seen:
            if item not in duplicates: duplicates.append(item)
        else:
            seen.append(item)
    return duplicates