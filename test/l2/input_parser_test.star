input_parser = import_module("/src/l2/input_parser.star")
participant_input_parser = import_module("/src/l2/participant/input_parser.star")

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_default_network_id = 1000
_default_registry = _registry.Registry()

_shared_defaults = {
    "extra_env_vars": {},
    "extra_labels": {},
    "extra_params": [],
    "log_level": None,
    "max_cpu": 0,
    "max_mem": 0,
    "min_cpu": 0,
    "min_mem": 0,
    "tolerations": [],
    "volume_size": 0,
}


def test_l2_input_parser_empty(plan):
    expect.eq(
        input_parser.parse(None, _default_registry),
        [],
    )
    expect.eq(
        input_parser.parse({}, _default_registry),
        [],
    )


def test_l2_input_parser_extra_attributes(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"node0": {"name": "peter", "extra": None}},
            _default_registry,
        ),
        "Invalid attributes in L2 configuration for node0: name,extra",
    )


def test_l2_input_parser_invalid_network_id(plan):
    expect.fails(
        lambda: input_parser.parse({"node-0": None}, _default_registry),
        "L2 ID must be a positive integer in decimal base, got node-0",
    )


def test_l2_input_parser_defaults(plan):
    expect.eq(
        input_parser.parse({"1": None}, _default_registry),
        [struct(network_id=1, participants=[])],
    )

    participants = {"node0": {}, "node1": None}
    parsed_participants = participant_input_parser.parse(
        participants, 1, _default_registry
    )
    expect.eq(
        input_parser.parse({"1": {"participants": participants}}, _default_registry),
        [struct(network_id=1, participants=parsed_participants)],
    )
