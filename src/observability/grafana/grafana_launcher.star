util = import_module("../../util.star")

ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

SERVICE_NAME = "grafana"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER_UINT16 = 3000

TEMPLATES_FILEPATH = "./templates"

DATASOURCE_CONFIG_TEMPLATE_FILEPATH = TEMPLATES_FILEPATH + "/datasource.yml.tmpl"
DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH = TEMPLATES_FILEPATH + "/dashboard-providers.yml.tmpl"

DATASOURCE_UID = "grafanacloud-prom"
DATASOURCE_CONFIG_REL_FILEPATH = "datasources/datasource.yml"

# this is relative to the files artifact root
DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH = "dashboards/dashboard-providers.yml"

CONFIG_DIRPATH_ON_SERVICE = "/config"
DASHBOARDS_DIRPATH_ON_SERVICE = "/dashboards"

USED_PORTS = {
    HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
        HTTP_PORT_NUMBER_UINT16,
        ethereum_package_shared_utils.TCP_PROTOCOL,
        ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_grafana(
    plan,
    prometheus_private_url,
    global_node_selectors,
    grafana_params,
):
    datasource_config_template = read_file(DATASOURCE_CONFIG_TEMPLATE_FILEPATH)

    (
        grafana_config_artifact_name,
        grafana_dashboards_artifact_names,
    ) = upload_grafana_config(
        plan,
        datasource_config_template,
        prometheus_private_url,
        dashboard_sources=grafana_params.dashboard_sources,
    )

    config = get_config(
        grafana_config_artifact_name,
        grafana_dashboards_artifact_names,
        global_node_selectors,
        grafana_params,
    )

    service = plan.add_service(SERVICE_NAME, config)

    service_url = "http://{0}:{1}".format(
        service.ip_address, service.ports[HTTP_PORT_ID].number
    )

    upload_dashboards(plan, service_url, grafana_dashboards_artifact_names)

    return service_url


def upload_grafana_config(
    plan,
    datasource_config_template,
    prometheus_private_url,
    dashboard_sources=[],
):
    datasource_data = new_datasource_config_template_data(prometheus_private_url)
    datasource_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        datasource_config_template, datasource_data
    )

    template_and_data_by_rel_dest_filepath = {
        DATASOURCE_CONFIG_REL_FILEPATH: datasource_template_and_data,
    }

    grafana_config_artifact_name = plan.render_templates(
        template_and_data_by_rel_dest_filepath, name="grafana-config"
    )

    grafana_dashboards_artifact_names = upload_dashboards(
        plan, dashboard_sources
    )

    return (
        grafana_config_artifact_name,
        grafana_dashboards_artifact_names,
    )


def new_datasource_config_template_data(prometheus_url):
    return {
        "PrometheusUID": DATASOURCE_UID,
        "PrometheusURL": prometheus_url
    }


def get_config(
    grafana_config_artifact_name,
    grafana_dashboards_artifact_names,
    node_selectors,
    grafana_params,
):
    return ServiceConfig(
        image=grafana_params.image,
        ports=USED_PORTS,
        env_vars={
            "GF_PATHS_PROVISIONING": CONFIG_DIRPATH_ON_SERVICE,
            "GF_AUTH_ANONYMOUS_ENABLED": "true",
            "GF_AUTH_ANONYMOUS_ORG_ROLE": "Admin",
            "GF_AUTH_ANONYMOUS_ORG_NAME": "Main Org.",
            # "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH": "/dashboards/default.json",
        },
        files={
            CONFIG_DIRPATH_ON_SERVICE: grafana_config_artifact_name,
        },
        min_cpu=grafana_params.min_cpu,
        max_cpu=grafana_params.max_cpu,
        min_memory=grafana_params.min_mem,
        max_memory=grafana_params.max_mem,
        node_selectors=node_selectors,
    )


def upload_dashboards(plan, service_url, grafana_dashboards_artifact_names):
    def grr_push(dir):
        return "grr push \"$DASHBOARDS_DIR/{0}\" -e --disable-reporting".format(dir)

    def grr_push_dashboards(i):
        return [
            grr_push("dashboards-{0}/folders".format(i)),
            grr_push("dashboards-{0}/dashboards".format(i)),
        ]

    grr_commands = [
        "grr config create-context kurtosis",
    ]

    for i in range(len(grafana_dashboards_artifact_names)):
        grr_commands += grr_push_dashboards(i)

    plan.run_sh(
        description="upload dashboards",
        image="grafana/grizzly:main-0b88d01",
        env_vars={
            "GRAFANA_URL": service_url,
            "DASHBOARDS_DIR": DASHBOARDS_DIRPATH_ON_SERVICE,
        },
        files={
            "{0}/dashboards-{1}".format(DASHBOARDS_DIRPATH_ON_SERVICE, i): grafana_dashboards_artifact_names[i]
            for i in range(len(grafana_dashboards_artifact_names))
        },
        run=util.multiline_cmd(grr_commands),
    )
