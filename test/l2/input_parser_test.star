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
            {"network0": {"name": "peter", "extra": None}},
            _default_registry,
        ),
        "Invalid attributes in L2 configuration for network0: name,extra",
    )


def test_l2_input_parser_invalid_name(plan):
    expect.fails(
        lambda: input_parser.parse({"network-0": None}, _default_registry),
        "ID cannot contain '-': network-0",
    )


def test_l2_input_parser_invalid_network_id(plan):
    expect.fails(
        lambda: input_parser.parse(
            {"network0": {"network_params": {"network_id": "x"}}}, _default_registry
        ),
        "L2 ID must be a positive integer in decimal base, got x",
    )

    expect.fails(
        lambda: input_parser.parse(
            {"network0": {"network_params": {"network_id": "0x1"}}}, _default_registry
        ),
        "L2 ID must be a positive integer in decimal base, got ",
    )


def test_l2_input_parser_defaults(plan):
    _default_network_params = struct(
        fjord_time_offset=0,
        fund_dev_accounts=True,
        granite_time_offset=0,
        holocene_time_offset=None,
        interop_time_offset=None,
        isthmus_time_offset=None,
        network="kurtosis",
        network_id=2151908,
        seconds_per_slot=2,
    )
    expect.eq(
        input_parser.parse({"network1": None}, _default_registry),
        [struct(network_params=_default_network_params, participants=[])],
    )

    participants = {"node0": {}, "node1": None}
    parsed_participants = participant_input_parser.parse(
        participants, 2151908, _default_registry
    )
    expect.eq(
        input_parser.parse(
            {"network1": {"participants": participants}}, _default_registry
        ),
        [
            struct(
                network_params=_default_network_params, participants=parsed_participants
            )
        ],
    )


def test_l2_input_parser_auto_network_id(plan):
    parsed = input_parser.parse(
        {"network0": None, "network1": None, "network2": None}, _default_registry
    )

    expect.eq(parsed[0].network_params.network_id, 2151908)
    expect.eq(parsed[1].network_params.network_id, 2151909)
    expect.eq(parsed[2].network_params.network_id, 2151910)

    parsed = input_parser.parse(
        {
            "network0": None,
            "network1": {"network_params": {"network_id": 7}},
            "network2": None,
        },
        _default_registry,
    )

    expect.eq(parsed[0].network_params.network_id, 2151908)
    expect.eq(parsed[1].network_params.network_id, 7)
    expect.eq(parsed[2].network_params.network_id, 2151909)

    expect.fails(lambda: input_parser.parse(
        {
            "network0": None,
            "network1": {"network_params": {"network_id": 2151908}},
            "network2": None,
        },
        _default_registry,
    ), "L2 IDs must be unique, got duplicates: 2151908")
