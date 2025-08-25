_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "enabled": False,
    "image": None,
    "global_connections_limit": 100,
    "log_format": "text",
    "log_level": "info",
    "message_buffer_size": 20,
    "per_ip_connections_limit": 10,
}

_IMAGE_IDS = {
    "flashblocks-websocket-proxy": _registry.FLASHBLOCKS_WEBSOCKET_PROXY,
}


def parse(websocket_proxy_args, network_params, registry):
    network_id = network_params.network_id
    network_name = network_params.name

    _filter.assert_keys(
        websocket_proxy_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in flashblocks websocket proxy configuration for network {}".format(
            network_name
        ),
    )

    websocket_proxy_params = _DEFAULT_ARGS | _filter.remove_none(
        websocket_proxy_args or {}
    )

    if not websocket_proxy_params["enabled"]:
        return None

    websocket_proxy_params["image"] = websocket_proxy_params["image"] or registry.get(
        _registry.FLASHBLOCKS_WEBSOCKET_PROXY
    )

    websocket_proxy_params["service_name"] = "flashblocks-websocket-proxy-{}-{}".format(
        network_id, network_name
    )

    websocket_proxy_params["labels"] = {
        "op.kind": "flashblocks-websocket-proxy",
        "op.network.id": str(network_id),
        "op.service.type": "websocket-proxy",
    }

    websocket_proxy_params["ports"] = {
        _net.WS_PORT_NAME: _net.port(number=8545, application_protocol="ws"),
    }

    return struct(**websocket_proxy_params)
