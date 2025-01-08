prometheus = import_module("github.com/kurtosis-tech/prometheus-package/main.star")

EXECUTION_CLIENT_TYPE = "execution"

METRICS_INFO_NAME_KEY = "name"
METRICS_INFO_URL_KEY = "url"
METRICS_INFO_PATH_KEY = "path"
METRICS_INFO_ADDITIONAL_CONFIG_KEY = "config"

PROMETHEUS_DEFAULT_SCRAPE_INTERVAL = "15s"


REGISTERED_METRICS_JOBS = []

def register_metrics_job(metrics_job):
    REGISTERED_METRICS_JOBS.append(metrics_job)

def launch_prometheus(
    plan,
    metrics_jobs,
    global_node_selectors,
    prometheus_params,
):
    if REGISTERED_METRICS_JOBS.length == 0:
        return None

    prometheus_url = prometheus.run(
        plan,
        REGISTERED_METRICS_JOBS,
        "prometheus",
        min_cpu=prometheus_params.min_cpu,
        max_cpu=prometheus_params.max_cpu,
        min_memory=prometheus_params.min_mem,
        max_memory=prometheus_params.max_mem,
        node_selectors=global_node_selectors,
        storage_tsdb_retention_time=prometheus_params.storage_tsdb_retention_time,
        storage_tsdb_retention_size=prometheus_params.storage_tsdb_retention_size,
        image=prometheus_params.image,
    )

    return prometheus_url

def new_metrics_job(
    job_name,
    endpoint,
    metrics_path,
    labels,
    scrape_interval=PROMETHEUS_DEFAULT_SCRAPE_INTERVAL,
):
    return {
        "Name": job_name,
        "Endpoint": endpoint,
        "MetricsPath": metrics_path,
        "Labels": labels,
        "ScrapeInterval": scrape_interval,
    }

def register_node_metrics_job(node_metrics_info):
    labels = {
        "service": el_context.service_name,
        "client_type": EXECUTION_CLIENT_TYPE,
        "client_name": el_context.client_name,
    }

    scrape_interval = PROMETHEUS_DEFAULT_SCRAPE_INTERVAL
    
    additional_config = node_metrics_info[
        METRICS_INFO_ADDITIONAL_CONFIG_KEY
    ]

    if additional_config != None:
        if additional_config.labels != None:
            labels.update(additional_config.labels)
        if (
            additional_config.scrape_interval != None
            and additional_config.scrape_interval != ""
        ):
            scrape_interval = additional_config.scrape_interval

    register_metrics_job(
        new_metrics_job(
            job_name=node_metrics_info[METRICS_INFO_NAME_KEY],
            endpoint=node_metrics_info[METRICS_INFO_URL_KEY],
            metrics_path=node_metrics_info[METRICS_INFO_PATH_KEY],
            labels=labels,
            scrape_interval=scrape_interval,
        )
    )
