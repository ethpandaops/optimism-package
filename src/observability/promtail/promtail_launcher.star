constants = import_module("../../package_io/constants.star")
util = import_module("../../util.star")

ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

SERVICE_NAME = "promtail"
HTTP_PORT_NUMBER = 9080
GRPC_PORT_NUMBER = 0

TEMPLATES_FILEPATH = "./templates"

CONFIG_TEMPLATE_FILEPATH = TEMPLATES_FILEPATH + "/promtail-config.yaml.tmpl"
CONFIG_REL_FILEPATH = "promtail-config.yaml"

CONFIG_DIRPATH_ON_SERVICE = "/config"

USED_PORTS = {
    constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        ethereum_package_shared_utils.TCP_PROTOCOL,
        ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
    ),
    "grpc": ethereum_package_shared_utils.new_port_spec(
        GRPC_PORT_NUMBER,
        ethereum_package_shared_utils.TCP_PROTOCOL,
        "grpc",
    ),
}


def launch_promtail(
    plan,
    global_node_selectors,
    loki_url,
    promtail_params,
):
    config_template = read_file(CONFIG_TEMPLATE_FILEPATH)

    config_artifact_name = create_config_artifact(
        plan,
        config_template,
        loki_url,
    )

    service_config = get_service_config(
        config_artifact_name,
        global_node_selectors,
        promtail_params,
    )

    service = plan.add_service(SERVICE_NAME, service_config)

    service_url = util.make_service_http_url(service)

    return service_url


def create_config_artifact(
    plan,
    config_template,
    loki_url,
):
    config_data = {
        "Ports": {
            "http": HTTP_PORT_NUMBER,
            "grpc": GRPC_PORT_NUMBER,
        },
        "LokiURL": loki_url,
    }
    config_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        config_template, config_data
    )

    template_and_data_by_rel_dest_filepath = {
        CONFIG_REL_FILEPATH: config_template_and_data,
    }

    config_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, name="promtail-config"
    )

    return config_artifact_name


def get_service_config(
    config_artifact_name,
    node_selectors,
    promtail_params,
):
    return ServiceConfig(
        image=promtail_params.image,
        ports=USED_PORTS,
        cmd=[
            "-config.file=" + CONFIG_DIRPATH_ON_SERVICE
        ],
        files={
            CONFIG_DIRPATH_ON_SERVICE: config_artifact_name,
        },
        min_cpu=promtail_params.min_cpu,
        max_cpu=promtail_params.max_cpu,
        min_memory=promtail_params.min_mem,
        max_memory=promtail_params.max_mem,
        node_selectors=node_selectors,
    )
