ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

constants = import_module("../package_io/constants.star")
util = import_module("../util.star")

observability = import_module("../observability/observability.star")
prometheus = import_module("../observability/prometheus/prometheus_launcher.star")

# Port nums
HTTP_PORT_NUM = 8080
METRICS_PORT_NUM = 7300

TEMPLATES_FILEPATH = "./templates"

CONFIG_FILE_NAME = "proxyd.toml"
CONFIG_TEMPLATE_FILEPATH = "{0}/{1}.tmpl".format(TEMPLATES_FILEPATH, CONFIG_FILE_NAME)

CONFIG_DIRPATH_ON_SERVICE = "/etc/proxyd"


def get_used_ports():
    used_ports = {
        constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch(
    plan,
    proxyd_params,
    network_params,
    el_contexts,
    observability_helper,
):
    config_template = read_file(CONFIG_TEMPLATE_FILEPATH)

    config_artifact_name = create_config_artifact(
        plan,
        config_template,
        network_params,
        el_contexts,
        observability_helper,
    )

    config = get_proxyd_config(
        plan,
        proxyd_params,
        config_artifact_name,
        observability_helper,
    )

    service = plan.add_service("proxyd-{0}".format(network_params.network_id), config)
    service_url = util.make_service_http_url(service)

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service_url


def create_config_artifact(
    plan,
    config_template,
    network_params,
    el_contexts,
    observability_helper,
):
    config_data = {
        "Ports": {
            "rpc": HTTP_PORT_NUM,
        },
        "Metrics": {
            "enabled": observability_helper.enabled,
            "port": METRICS_PORT_NUM,
        },
        "Replicas": {
            "{0}-{1}".format(el_context.client_name, num): el_context.rpc_http_url
            for num, el_context in enumerate(el_contexts)
        },
    }

    config_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        config_template, config_data
    )

    config_artifact_name = plan.render_templates(
        {
            CONFIG_FILE_NAME: config_template_and_data,
        },
        name="proxyd-config-{0}".format(network_params.network_id),
    )

    return config_artifact_name


def get_proxyd_config(
    plan,
    proxyd_params,
    config_artifact_name,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = [
        "proxyd",
        "{0}/{1}".format(CONFIG_DIRPATH_ON_SERVICE, CONFIG_FILE_NAME),
    ]

    # apply customizations

    if observability_helper.enabled:
        observability.expose_metrics_port(ports, port_num=METRICS_PORT_NUM)

    cmd += proxyd_params.extra_params

    return ServiceConfig(
        image=proxyd_params.image,
        ports=ports,
        cmd=cmd,
        files={
            CONFIG_DIRPATH_ON_SERVICE: config_artifact_name,
        },
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
