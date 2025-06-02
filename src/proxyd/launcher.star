_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_net = import_module("/src/util/net.star")
_observability = import_module("../observability/observability.star")

# Port nums
_METRICS_PORT_NUM = 7300

_TEMPLATES_FILEPATH = "./templates"

_CONFIG_FILE_NAME = "proxyd.toml"
_CONFIG_TEMPLATE_FILEPATH = "{0}/{1}.tmpl".format(
    _TEMPLATES_FILEPATH, _CONFIG_FILE_NAME
)

_CONFIG_DIRPATH_ON_SERVICE = "/etc/proxyd"


def launch(
    plan,
    params,
    network_params,
    observability_helper,
):
    config_artifact_name = create_config_artifact(
        plan=plan,
        params=params,
        network_params=network_params,
        observability_helper=observability_helper,
    )

    config = get_service_config(
        plan=plan,
        params=params,
        config_artifact_name=config_artifact_name,
        observability_helper=observability_helper,
    )

    service = plan.add_service(params.service_name, config)

    _observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return struct(service=service)


def create_config_artifact(
    plan,
    params,
    network_params,
    observability_helper,
):
    config_template = read_file(_CONFIG_TEMPLATE_FILEPATH)
    config_data = {
        "Ports": {
            "rpc": params.ports[_net.HTTP_PORT_NAME].number,
        },
        "Metrics": {
            "enabled": observability_helper.enabled,
            "port": _METRICS_PORT_NUM,
        },
        "Replicas": params.replicas,
    }

    return plan.render_templates(
        {
            _CONFIG_FILE_NAME: struct(
                template=config_template,
                data=config_data,
            ),
        },
        name="proxyd-config-{0}".format(network_params.network_id),
    )


def get_service_config(
    plan,
    params,
    config_artifact_name,
    observability_helper,
):
    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "proxyd",
        "{0}/{1}".format(_CONFIG_DIRPATH_ON_SERVICE, _CONFIG_FILE_NAME),
    ] + params.extra_params

    # apply customizations

    if observability_helper.enabled:
        _observability.expose_metrics_port(ports, port_num=_METRICS_PORT_NUM)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        cmd=cmd,
        files={
            _CONFIG_DIRPATH_ON_SERVICE: config_artifact_name,
        },
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
        labels=params.labels,
    )
