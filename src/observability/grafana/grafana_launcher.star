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
    dashboard_providers_config_template = read_file(DASHBOARD_PROVIDERS_CONFIG_TEMPLATE_FILEPATH)

    (
        grafana_config_artifact_name,
        grafana_dashboards_artifact_names,
    ) = upload_grafana_config(
        plan,
        datasource_config_template,
        dashboard_providers_config_template,
        prometheus_private_url,
        dashboard_sources=grafana_params.dashboard_sources,
    )

    config = get_config(
        grafana_config_artifact_name,
        grafana_dashboards_artifact_names,
        global_node_selectors,
        grafana_params,
    )

    plan.add_service(SERVICE_NAME, config)


def upload_grafana_config(
    plan,
    datasource_config_template,
    dashboard_providers_config_template,
    prometheus_private_url,
    dashboard_sources=[],
):
    datasource_data = new_datasource_config_template_data(prometheus_private_url)
    datasource_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        datasource_config_template, datasource_data
    )

    dashboard_providers_data = new_dashboard_providers_config_template_data(
        DASHBOARDS_DIRPATH_ON_SERVICE
    )
    dashboard_providers_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        dashboard_providers_config_template, dashboard_providers_data
    )

    template_and_data_by_rel_dest_filepath = {
        DATASOURCE_CONFIG_REL_FILEPATH: datasource_template_and_data,
        DASHBOARD_PROVIDERS_CONFIG_REL_FILEPATH: dashboard_providers_template_and_data,
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


def new_dashboard_providers_config_template_data(dashboards_dirpath):
    return {"DashboardsDirpath": dashboards_dirpath}


def upload_dashboards(plan, dashboard_sources):
    dashboard_artifact_names = []

    for index, dashboard_src in enumerate(dashboard_sources):
        dashboard_name = "grafana-dashboards-{0}".format(index)

        dashboard_artifact_name = plan.upload_files(
            dashboard_src, name=dashboard_name
        )
        dashboard_artifact_names.append(dashboard_artifact_name)

    return dashboard_artifact_names


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
            DASHBOARDS_DIRPATH_ON_SERVICE: Directory(
                artifact_names=grafana_dashboards_artifact_names,
            ),
        },
        min_cpu=grafana_params.min_cpu,
        max_cpu=grafana_params.max_cpu,
        min_memory=grafana_params.min_mem,
        max_memory=grafana_params.max_mem,
        node_selectors=node_selectors,
    )
