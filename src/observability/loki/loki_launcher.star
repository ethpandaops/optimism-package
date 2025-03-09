_imports = import_module("/imports.star")

_constants = _imports.load_module("src/package_io/constants.star")
_util = _imports.load_module("src/util.star")

_ethereum_package_shared_utils = _imports.ext.ethereum_package_shared_utils

SERVICE_NAME = "loki"
HTTP_PORT_NUMBER = 3100
GRPC_PORT_NUMBER = 9096

TEMPLATES_FILEPATH = "./templates"

CONFIG_TEMPLATE_FILEPATH = TEMPLATES_FILEPATH + "/loki-config.yaml.tmpl"
CONFIG_REL_FILEPATH = "loki-config.yaml"

CONFIG_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
    _constants.HTTP_PORT_ID: _ethereum_package_shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        _ethereum_package_shared_utils.TCP_PROTOCOL,
        _ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    "grpc": _ethereum_package_shared_utils.new_port_spec(
        GRPC_PORT_NUMBER,
        _ethereum_package_shared_utils.TCP_PROTOCOL,
        "grpc",
    ),
}


def launch_loki(
    plan,
    global_node_selectors,
    loki_params,
):
    config_template = read_file(CONFIG_TEMPLATE_FILEPATH)

    config_artifact_name = create_config_artifact(
        plan,
        config_template,
    )

    service_config = get_service_config(
        config_artifact_name,
        global_node_selectors,
        loki_params,
    )

    service = plan.add_service(SERVICE_NAME, service_config)

    service_url = _util.make_service_http_url(service)

    return service_url


def create_config_artifact(
    plan,
    config_template,
):
    config_data = {
        "Ports": {
            "http": HTTP_PORT_NUMBER,
            "grpc": GRPC_PORT_NUMBER,
        },
    }
    config_template_and_data = _ethereum_package_shared_utils.new_template_and_data(
        config_template, config_data
    )

    template_and_data_by_rel_dest_filepath = {
        CONFIG_REL_FILEPATH: config_template_and_data,
    }

    config_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, name="loki-config"
    )

    return config_artifact_name


def get_service_config(
    config_artifact_name,
    node_selectors,
    loki_params,
):
    return ServiceConfig(
        image=loki_params.image,
        ports=USED_PORTS,
        cmd=[
            "-config.file={0}/{1}".format(
                CONFIG_DIRPATH_ON_SERVICE, CONFIG_REL_FILEPATH
            ),
        ],
        files={
            CONFIG_DIRPATH_ON_SERVICE: config_artifact_name,
        },
        min_cpu=loki_params.min_cpu,
        max_cpu=loki_params.max_cpu,
        min_memory=loki_params.min_mem,
        max_memory=loki_params.max_mem,
        node_selectors=node_selectors,
    )
