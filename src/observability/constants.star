ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_node_metrics = import_module(
    "github.com/ethpandaops/ethereum-package/src/node_metrics_info.star"
)


METRICS_PORT_ID = "metrics"
METRICS_PORT_NUM = 9001
METRICS_PATH = "/debug/metrics/prometheus"

def make_metrics_url(service, metrics_port_num=METRICS_PORT_NUM):
    return "{0}:{1}".format(service.ip_address, metrics_port_num)

def new_metrics_info(service, metrics_path=METRICS_PATH):
    metrics_url = make_metrics_url(service.ip_address)
    metrics_info = ethereum_package_node_metrics.new_node_metrics_info(
        service.name, metrics_path, metrics_url
    )

    return metrics_info

def expose_metrics_port(ports, port_id=METRICS_PORT_ID, port_num=METRICS_PORT_NUM):
    ports[port_id] = ethereum_package_shared_utils.new_port_spec(
        port_num, ethereum_package_shared_utils.TCP_PROTOCOL
    )

# configures the CLI flags and ports for a service using the standard op-service setup
def configure_op_service_metrics(cmd, ports):
    cmd += [
            "--metrics.enabled",
            "--metrics.addr=0.0.0.0",
            "--metrics.port={0}".format(METRICS_PORT_NUM),
        ]
        
    expose_metrics_port(ports)
