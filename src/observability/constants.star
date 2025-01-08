METRICS_PORT_ID = "metrics"
METRICS_PORT_NUM = 9001
METRICS_PATH = "/debug/metrics/prometheus"

def new_metrics_info(service):
    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    metrics_info = ethereum_package_node_metrics.new_node_metrics_info(
        service.name, METRICS_PATH, metrics_url
    )

    return metrics_info
