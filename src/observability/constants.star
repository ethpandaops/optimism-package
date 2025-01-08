METRICS_PORT_ID = "metrics"
METRICS_PORT_NUM = 9001
METRICS_PATH = "/debug/metrics/prometheus"

def new_metrics_info(service):
    metrics_url = "{0}:{1}".format(service.ip_address, METRICS_PORT_NUM)
    metrics_info = ethereum_package_node_metrics.new_node_metrics_info(
        service.name, METRICS_PATH, metrics_url
    )

    return metrics_info

def expose_metrics_port(ports, port_id=METRICS_PORT_ID, port_num=METRICS_PORT_NUM):
    ports[port_id] = ethereum_package_shared_utils.new_port_spec(
        port_num, ethereum_package_shared_utils.TCP_PROTOCOL
    )
