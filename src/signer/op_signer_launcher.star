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

CONFIG_FILE_NAME = "config.yaml"
CONFIG_TEMPLATE_FILEPATH = "{0}/{1}.tmpl".format(TEMPLATES_FILEPATH, CONFIG_FILE_NAME)

CONFIG_DIRPATH_ON_SERVICE = "/app"
# KEY_DIRPATH_ON_SERVICE = "/{0}/tls".format(CONFIG_DIRPATH_ON_SERVICE)

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
    signer_params,
    network_params,
    clients,
    observability_helper,
):
    service_name = "op-signer-{0}".format(network_params.network)

    client_key_artifacts = create_key_artifact(
        plan,
        clients,
    )

    config_template = read_file(CONFIG_TEMPLATE_FILEPATH)

    config_artifact_name = create_config_artifact(
        plan,
        service_name,
        config_template,
        client_key_artifacts,
        observability_helper,
    )

    config = get_signer_config(
        plan,
        signer_params,
        config_artifact_name,
        client_key_artifacts,
        observability_helper,
    )

    service = plan.add_service(service_name, config)
    service_url = util.make_service_http_url(service)

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service_url

def create_key_artifact(
    plan,
    clients,
):
    keyDir = "/keys"

    client_key_artifacts = {}

    for client_hostname, client_key in clients.items():
        client_key_file = util.write_to_file(
            plan,
            client_key,
            keyDir,
            "{0}_key.pem".format(client_hostname),
        )
        client_key_artifacts[client_hostname] = client_key_file

    return client_key_artifacts

def create_config_artifact(
    plan,
    service_name,
    config_template,
    client_key_artifacts,
    observability_helper,
):
    config_data = {
        "Clients": client_key_artifacts,
    }

    config_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        config_template, config_data
    )

    config_artifact_name = plan.render_templates(
        {
            CONFIG_FILE_NAME: config_template_and_data,
        },
        name="{0}-config".format(service_name),
    )

    return config_artifact_name


def get_signer_config(
    plan,
    signer_params,
    config_artifact_name,
    client_key_artifacts,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = []

    # apply customizations

    if observability_helper.enabled:
        observability.expose_metrics_port(ports, port_num=METRICS_PORT_NUM)
    
    cmd += signer_params.extra_params

    return ServiceConfig(
        image="{0}:{1}".format(signer_params.image, signer_params.tag),
        ports=ports,
        # env_vars={
        #     "OP_SIGNER_SERVER_CA": "{0}/ca.crt".format(KEY_DIRPATH_ON_SERVICE),
        #     "OP_SIGNER_SERVER_CERT": "{0}/tls.crt".format(KEY_DIRPATH_ON_SERVICE),
        #     "OP_SIGNER_SERVER_KEY": "{0}/tls.key".format(KEY_DIRPATH_ON_SERVICE),
        # },
        files={
            CONFIG_DIRPATH_ON_SERVICE: Directory(
                artifact_names=[config_artifact_name] +
                    [
                        client_key_artifacts[client_hostname]
                        for client_hostname in client_key_artifacts
                    ]
            )
        },
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )
