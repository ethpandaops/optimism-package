_input_parser = import_module("/src/batcher/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_l2_name = "my-l2"
_default_registry = _registry.Registry()


def test_batcher_input_parser_extra_attrbutes(plan):
    expect.fails(
        lambda: _input_parser.parse(
            {"extra": None, "name": "x"},
            _default_l2_name,
            _default_registry,
        ),
        " Invalid attributes in batcher configuration for my-l2: extra,name",
    )


def test_batcher_input_parser_default_args(plan):
    _default_params = struct(
        image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:develop",
        extra_params=[],
        ports={
            _net.HTTP_PORT_NAME: _net.port(number=8548),
        },
        service_name="op-batcher-my-l2",
    )

    expect.eq(
        _input_parser.parse(
            None,
            _default_l2_name,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            {},
            _default_l2_name,
            _default_registry,
        ),
        _default_params,
    )

    expect.eq(
        _input_parser.parse(
            {
                "image": None,
                "extra_params": None,
            },
            _default_l2_name,
            _default_registry,
        ),
        _default_params,
    )


def test_batcher_input_parser_custom_params(plan):
    parsed = _input_parser.parse(
        {
            "image": "op-proposer:brightest",
            "extra_params": ["--hola"],
        },
        _default_l2_name,
        _default_registry,
    )

    expect.eq(
        parsed,
        struct(
            extra_params=["--hola"],
            image="op-proposer:brightest",
            ports={
                _net.HTTP_PORT_NAME: _net.port(number=8548),
            },
            service_name="op-batcher-my-l2",
        ),
    )


def test_batcher_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.OP_BATCHER: "op-batcher:greatest"})

    parsed = _input_parser.parse(
        {},
        _default_l2_name,
        registry,
    )
    expect.eq(parsed.image, "op-batcher:greatest")

    parsed = _input_parser.parse(
        {"image": "op-batcher:oldest"},
        _default_l2_name,
        registry,
    )
    expect.eq(parsed.image, "op-batcher:oldest")
