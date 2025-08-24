launcher = import_module("/src/conductor/op-conductor/launcher.star")
_net = import_module("/src/util/net.star")
_observability = import_module("/src/observability/observability.star")

_default_params = struct(
    service_name="op-conductor-1000-node0",
    image="op-conductor:latest",
    admin=True,
    proxy=True,
    paused=False,
    bootstrap=False,
    pprof_enabled=False,
    websocket_enabled=True,
    healthcheck_interval=2,
    healthcheck_min_peer_count=1,
    raft_heartbeat_timeout="900ms",
    raft_lease_timeout="550ms",
    raft_snapshot_threshold=1024,
    raft_trailing_logs=3600,
    labels={
        "op.kind": "conductor",
        "op.network.id": "1000",
    },
    ports={
        _net.RPC_PORT_NAME: _net.port(number=8547),
        _net.CONSENSUS_PORT_NAME: _net.port(number=50050),
        _net.WS_PORT_NAME: _net.port(number=8546, application_protocol="ws"),
    },
)

_default_network_params = struct(
    network_id=1000,
    seconds_per_slot=2,
)

_default_el_params = struct(
    service_name="op-el-1000-node0",
    ports={
        _net.RPC_PORT_NAME: _net.port(number=8545),
    },
)

_default_cl_params = struct(
    service_name="op-cl-1000-node0",
    ports={
        _net.RPC_PORT_NAME: _net.port(number=8546),
    },
)

_default_observability_helper = _observability.make_helper(
    struct(enabled=True, metrics=struct(port=9001))
)


def test_op_conductor_launcher_with_el_builder_params(plan):
    el_builder_params = struct(
        service_name="op-elbuilder-1000-node0",
        ports={
            _net.FLASHBLOCKS_WS_PORT_NAME: _net.port(
                number=1111, application_protocol="ws"
            ),
        },
    )

    # Mock sidecar context to enable rollup boost
    sidecar_context = struct(rpc_http_url="http://rollup-boost:8545")

    service_config = launcher.get_service_config(
        plan=plan,
        params=_default_params,
        network_params=_default_network_params,
        supervisors_params=[],
        sidecar_context=sidecar_context,
        deployment_output="deployment_output",
        el_params=_default_el_params,
        cl_params=_default_cl_params,
        el_builder_params=el_builder_params,
        observability_helper=_default_observability_helper,
    )

    expect.eq(service_config.image, _default_params.image)
    expect.eq(service_config.labels, _default_params.labels)

    # Check that el_builder_params integration works when sidecar_context is present
    expect.eq(
        service_config.env_vars["OP_CONDUCTOR_ROLLUPBOOST_WS_URL"],
        "ws://op-elbuilder-1000-node0:1111/ws",
    )
    expect.eq(service_config.env_vars["OP_CONDUCTOR_ROLLUP_BOOST_ENABLED"], "true")


def test_op_conductor_launcher_without_el_builder_params(plan):
    service_config = launcher.get_service_config(
        plan=plan,
        params=_default_params,
        network_params=_default_network_params,
        supervisors_params=[],
        sidecar_context=None,
        deployment_output="deployment_output",
        el_params=_default_el_params,
        cl_params=_default_cl_params,
        el_builder_params=None,
        observability_helper=_default_observability_helper,
    )

    expect.eq(service_config.image, _default_params.image)

    # Check that el_builder_params integration is not present
    expect.fails(
        lambda: service_config.env_vars["OP_CONDUCTOR_ROLLUPBOOST_WS_URL"],
        'key "OP_CONDUCTOR_ROLLUPBOOST_WS_URL" not in dict',
    )
    expect.eq(service_config.env_vars["OP_CONDUCTOR_ROLLUP_BOOST_ENABLED"], "false")


def test_op_conductor_launcher_with_el_builder_params_no_sidecar(plan):
    el_builder_params = struct(
        service_name="op-elbuilder-1000-node0",
        ports={
            _net.FLASHBLOCKS_WS_PORT_NAME: _net.port(
                number=1111, application_protocol="ws"
            ),
        },
    )

    service_config = launcher.get_service_config(
        plan=plan,
        params=_default_params,
        network_params=_default_network_params,
        supervisors_params=[],
        sidecar_context=None,
        deployment_output="deployment_output",
        el_params=_default_el_params,
        cl_params=_default_cl_params,
        el_builder_params=el_builder_params,
        observability_helper=_default_observability_helper,
    )

    expect.eq(service_config.image, _default_params.image)
    expect.eq(service_config.labels, _default_params.labels)

    # Check that el_builder_params integration is not present without sidecar_context
    expect.fails(
        lambda: service_config.env_vars["OP_CONDUCTOR_ROLLUPBOOST_WS_URL"],
        'key "OP_CONDUCTOR_ROLLUPBOOST_WS_URL" not in dict',
    )
    expect.eq(service_config.env_vars["OP_CONDUCTOR_ROLLUP_BOOST_ENABLED"], "false")
