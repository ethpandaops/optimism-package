_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_WEBSOCKET_PROXY_ARGS = {
    "enabled": False,
    "image": None,
    "ports": None,
    "labels": None,
    "min_cpu": 0,
    "max_cpu": 0,
    "min_mem": 0,
    "max_mem": 0,
    "tolerations": None,
    "node_selectors": None,
}


def parse_websocket_proxy(
    websocket_proxy_args, network_params, registry
):
    network_id = network_params.network_id
    network_name = network_params.name

    _filter.assert_keys(
        websocket_proxy_args or {},
        _DEFAULT_WEBSOCKET_PROXY_ARGS.keys(),
        "Invalid attributes in flashblocks websocket proxy configuration for network {}".format(network_name),
    )

    websocket_proxy_params = _DEFAULT_WEBSOCKET_PROXY_ARGS | _filter.remove_none(websocket_proxy_args or {})

    if not websocket_proxy_params["enabled"]:
        return None

    websocket_proxy_params["image"] = websocket_proxy_params["image"] or registry.get(_registry.FLASHBLOCKS_WEBSOCKET_PROXY)

    websocket_proxy_params["service_name"] = "flashblocks-websocket-proxy-{}-{}".format(
        network_id, network_name
    )

    if websocket_proxy_params.get("ports"):
        custom_ports = {}
        for port_name, port_number in websocket_proxy_params["ports"].items():
            custom_ports[port_name] = _net.port(number=port_number)
        websocket_proxy_params["ports"] = custom_ports
    else:
        websocket_proxy_params["ports"] = {
            _net.WS_PORT_NAME: _net.port(number=8545),
            "metrics": _net.port(number=9000),
        }

    default_labels = {
        "op.kind": "flashblocks",
        "op.network.id": str(network_id),
        "op.service.type": "websocket-proxy",
    }
    if websocket_proxy_params.get("labels"):
        merged_labels = {}
        for key, value in default_labels.items():
            merged_labels[key] = value
        for key, value in websocket_proxy_params["labels"].items():
            merged_labels[key] = value
        websocket_proxy_params["labels"] = merged_labels
    else:
        websocket_proxy_params["labels"] = default_labels

    return struct(**websocket_proxy_params)
