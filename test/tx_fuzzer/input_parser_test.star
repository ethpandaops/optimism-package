_input_parser = import_module("/src/tx-fuzzer/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_params = struct(network_id=1000, name="my-l2", seconds_per_slot=2)
_default_registry = _registry.Registry()


def test_tx_fuzzer_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_network_params,
            _default_registry,
        ),
        "Invalid attributes in tx fuzzer configuration for my-l2: extra,name",
    )


def test_tx_fuzzer_input_parser_default_args(plan):
    expect.eq(
        _input_parser.parse(
            None,
            _default_network_params,
            _default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            {},
            _default_network_params,
            _default_registry,
        ),
        None,
    )

    expect.eq(
        _input_parser.parse(
            {
                "enabled": False,
                "image": None,
                "extra_params": None,
            },
            _default_network_params,
            _default_registry,
        ),
        None,
    )


def test_tx_fuzzer_input_parser_enabled_default_args(plan):
    _default_params = struct(
        enabled=True,
        extra_params=[],
        image="ethpandaops/tx-fuzz:master",
        labels={"op.kind": "tx-fuzzer", "op.network.id": "1000"},
        max_cpu=1000,
        max_memory=300,
        min_cpu=100,
        min_memory=20,
        service_name="op-tx-fuzzer-1000-my-l2",
    )

    expect.eq(
        _input_parser.parse(
            {
                "enabled": True,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            {
                "enabled": True,
                "image": None,
                "extra_params": None,
            },
            _default_network_params,
            _default_registry,
        ),
        _default_params,
    )


def test_tx_fuzzer_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        {
            "enabled": True,
            "image": "op-tx-fuzzer:brightest",
            "extra_params": ["--spicy"],
        },
        _default_network_params,
        _default_registry,
    )

    expect.eq(
        parsed,
        struct(
            enabled=True,
            extra_params=["--spicy"],
            image="op-tx-fuzzer:brightest",
            labels={"op.kind": "tx-fuzzer", "op.network.id": "1000"},
            max_cpu=1000,
            max_memory=300,
            min_cpu=100,
            min_memory=20,
            service_name="op-tx-fuzzer-1000-my-l2",
        ),
    )


def test_tx_fuzzer_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.TX_FUZZER: "op-tx-fuzzer:greatest"})

    parsed = _input_parser.parse(
        {"enabled": True},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "op-tx-fuzzer:greatest")

    parsed = _input_parser.parse(
        {"enabled": True, "image": "op-tx-fuzzer:oldest"},
        _default_network_params,
        registry,
    )
    expect.eq(parsed.image, "op-tx-fuzzer:oldest")
