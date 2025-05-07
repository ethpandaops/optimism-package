_net = import_module("/src/util/net.star")


def test_net_port(plan):
    expect.eq(
        _net.port(number=1),
        struct(number=1, application_protocol="http", transport_protocol="TCP"),
    )
    expect.eq(
        _net.port(number=1, application_protocol="ws"),
        struct(number=1, application_protocol="ws", transport_protocol="TCP"),
    )


def test_net_port_to_port_spec(plan):
    port = _net.port(number=1)
    port_spec = _net.port_to_port_spec(port)

    expect.eq(port.number, port_spec.number)
    expect.eq(port.application_protocol, port_spec.application_protocol)
    expect.eq(port.transport_protocol, port_spec.transport_protocol)


def test_net_ports_to_port_specs(plan):
    ports = {
        "a": _net.port(number=1),
        "b": _net.port(number=2),
    }
    port_specs = _net.ports_to_port_specs(ports)

    expect.eq(ports.keys(), port_specs.keys())

    expect.eq(ports["a"].number, port_specs["a"].number)
    expect.eq(ports["a"].application_protocol, port_specs["a"].application_protocol)
    expect.eq(ports["a"].transport_protocol, port_specs["a"].transport_protocol)

    expect.eq(ports["b"].number, port_specs["b"].number)
    expect.eq(ports["b"].application_protocol, port_specs["b"].application_protocol)
    expect.eq(ports["b"].transport_protocol, port_specs["b"].transport_protocol)


def test_net_service_url(plan):
    http_port = _net.port(number=8888)
    http_port_spec = _net.port_to_port_spec(http_port)
    expect.eq(
        _net.service_url(service_name="local", service_port=http_port),
        "http://local:8888",
    )
    expect.eq(
        _net.service_url(service_name="local", service_port=http_port_spec),
        "http://local:8888",
    )

    wss_port = _net.port(number=9999, application_protocol="wss")
    wss_port_spec = _net.port_to_port_spec(wss_port)
    expect.eq(
        _net.service_url(service_name="local", service_port=wss_port),
        "wss://local:9999",
    )
    expect.eq(
        _net.service_url(service_name="local", service_port=wss_port_spec),
        "wss://local:9999",
    )
