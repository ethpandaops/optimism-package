input_parser = import_module("/src/package_io/input_parser.star")


def test_external_l1_network_params_input_parser_invalid_fields(plan):
    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan,
            {
                "invalid_key": "invalid_value",
            },
        ),
        "Invalid parameter invalid_key",
    )

    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan,
            {
                "empty_invalid_key": None,
            },
        ),
        "Invalid parameter empty_invalid_key",
    )


def test_external_l1_network_params_input_parser_missing_fields(plan):
    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(plan, {}),
        'key "network_id" not in dict',
    )

    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan, {"network_id": None}
        ),
        'key "rpc_kind" not in dict',
    )

    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan, {"network_id": None, "rpc_kind": None}
        ),
        'key "el_rpc_url" not in dict',
    )

    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan, {"network_id": None, "rpc_kind": None, "el_rpc_url": None}
        ),
        'key "el_ws_url" not in dict',
    )

    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan,
            {
                "network_id": None,
                "rpc_kind": None,
                "el_rpc_url": None,
                "el_ws_url": None,
            },
        ),
        'key "cl_rpc_url" not in dict',
    )

    expect.fails(
        lambda: input_parser.external_l1_network_params_input_parser(
            plan,
            {
                "network_id": None,
                "rpc_kind": None,
                "el_rpc_url": None,
                "el_ws_url": None,
                "cl_rpc_url": None,
            },
        ),
        'key "priv_key" not in dict',
    )


def test_external_l1_network_params_input_parser_set_fields(plan):
    params = {
        "network_id": "network_id",
        "rpc_kind": "rpc_kind",
        "el_rpc_url": "el_rpc_url",
        "el_ws_url": "el_ws_url",
        "cl_rpc_url": "cl_rpc_url",
        "priv_key": "priv_key",
    }
    parsed_params = input_parser.external_l1_network_params_input_parser(plan, params)

    expect.eq(parsed_params, struct(**params))

def test_interop_default_args(plan):
    parsed_params = input_parser.parse_network_params(plan, {})

    expect.eq(parsed_params["interop"], input_parser.default_interop_params())

def test_interop_supervisor_params(plan):
    supervisor_args = { "image": "supervisor.jpeg", "dependency_set": None, "extra_params": None }
    parsed_params = input_parser.parse_network_params(plan, {
        "interop": {
            "supervisor_params": supervisor_args,
        },
    })

    expect.eq(parsed_params["interop"], input_parser.default_interop_params() | {
        "supervisor_params": {
            "image": "supervisor.jpeg",
            "dependency_set": "",
            "extra_params": [],
        },
    })

def test_interop_default_set_params(plan):
    supervisor_args = { "image": "supervisor.jpeg" }
    parsed_params = input_parser.parse_network_params(plan, {
        "interop": {
            "supervisor_params": supervisor_args,
            "sets": [{}]
        },
    })

    expect.eq(parsed_params["interop"], input_parser.default_interop_params() | {
        "supervisor_params": input_parser.default_supervisor_params() | supervisor_args,
        "sets": [{
            "participants": [],
            "name": "interop-set-0",
            "supervisor_params": input_parser.default_supervisor_params() | supervisor_args
        }]
    })

def test_interop_set_params(plan):
    supervisor_args = { "image": "supervisor.jpeg" }
    parsed_params = input_parser.parse_network_params(plan, {
        "interop": {
            "supervisor_params": supervisor_args,
            "sets": [{}]
        },
    })

    expect.eq(parsed_params["interop"], input_parser.default_interop_params() | {
        "supervisor_params": input_parser.default_supervisor_params() | supervisor_args,
        "sets": [{
            "participants": [],
            "name": "interop-set-0",
            "supervisor_params": input_parser.default_supervisor_params() | supervisor_args
        }]
    })

def test_interop_set_none_params(plan):
    parsed_params = input_parser.parse_network_params(plan, {
        "interop": {
            "sets": [None]
        },
    })

    expect.eq(parsed_params["interop"], input_parser.default_interop_params() | {
        "sets": []
    })