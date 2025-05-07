input_parser = import_module("/src/supervisor/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_superchains = [
    struct(participants=[1000, 2000], name="superchain-0"),
    struct(participants=[3000], name="superchain-1"),
    struct(participants=[1000, 4000], name="superchain-2"),
]

_default_supervisor = struct(
    dependency_set={
        "dependencies": {
            "1000": {"chainIndex": "1000", "activationTime": 0, "historyMinTime": 0},
            "2000": {"chainIndex": "2000", "activationTime": 0, "historyMinTime": 0},
        }
    },
    extra_params=[],
    image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:develop",
    name="supervisor",
    ports={
        "rpc": _net.port(
            number=8545,
        )
    },
    service_name="op-supervisor-supervisor",
)

_default_registry = _registry.Registry()


def test_supervisor_input_parser_empty(plan):
    expect.eq(
        input_parser.parse(None, _superchains, _default_registry),
        [],
    )
    expect.eq(
        input_parser.parse({}, _superchains, _default_registry),
        [],
    )


def test_supervisor_input_parser_extra_attrbutes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"supervisor-0": {"extra": None, "name": "x"}},
            _superchains,
            _default_registry,
        ),
        "Invalid attributes in supervisor configuration for supervisor-0: extra,name",
    )


def test_supervisor_input_parser_missing_superchain_name(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"supervisor-0": {}},
            _superchains,
            _default_registry,
        ),
        "Missing superchain name for supervisor supervisor-0",
    )


def test_supervisor_input_parser_missing_superchain(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"supervisor-0": {"superchain": "superchain-hallucinated"}},
            _superchains,
            _default_registry,
        ),
        "Missing superchain superchain-hallucinated for supervisor supervisor-0",
    )


def test_supervisor_input_parser_default_args(plan):
    expect.eq(
        input_parser.parse(
            {
                "supervisor-0": {
                    "enabled": None,
                    "image": None,
                    "dependency_set": None,
                    "extra_params": None,
                    "superchain": "superchain-0",
                }
            },
            _superchains,
            _default_registry,
        ),
        [
            struct(
                dependency_set={
                    "dependencies": {
                        "1000": {
                            "chainIndex": "1000",
                            "activationTime": 0,
                            "historyMinTime": 0,
                        },
                        "2000": {
                            "chainIndex": "2000",
                            "activationTime": 0,
                            "historyMinTime": 0,
                        },
                    }
                },
                enabled=True,
                extra_params=[],
                image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:develop",
                name="supervisor-0",
                ports={
                    "rpc": _net.port(
                        number=8545,
                    )
                },
                service_name="op-supervisor-supervisor-0",
                superchain=_superchains[0],
            ),
        ],
    )


def test_supervisor_input_parser_custom_(plan):
    parsed = input_parser.parse(
        {
            "supervisor-0": {
                "superchain": "superchain-0",
                "dependency_set": {},
                "extra_params": ["--hey"],
            },
        },
        _superchains,
        _default_registry,
    )
    expect.eq(parsed[0].extra_params, ["--hey"])
    expect.eq(parsed[0].dependency_set, {})


def test_supervisor_input_parser_custom_registry(plan):
    registry = _registry.Registry({_registry.OP_SUPERVISOR: "op-supervisor:latest"})

    parsed = input_parser.parse(
        {
            "supervisor-0": {"superchain": "superchain-0"},
        },
        _superchains,
        registry,
    )
    expect.eq(parsed[0].image, "op-supervisor:latest")

    parsed = input_parser.parse(
        {
            "supervisor-0": {
                "superchain": "superchain-0",
                "image": "op-supervisor:oldest",
            },
        },
        _superchains,
        registry,
    )
    expect.eq(parsed[0].image, "op-supervisor:oldest")
