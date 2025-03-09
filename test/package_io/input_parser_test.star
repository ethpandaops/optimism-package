_imports = import_module("/imports.star")

_input_parser = _imports.load_module("src/package_io/input_parser.star")


def test_external_l1_network_params_input_parser_invalid_fields(_plan):
    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser(
            {
                "invalid_key": "invalid_value",
            },
        ),
        "Invalid parameter invalid_key",
    )

    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser(
            {
                "empty_invalid_key": None,
            },
        ),
        "Invalid parameter empty_invalid_key",
    )


def test_external_l1_network_params_input_parser_missing_fields(_plan):
    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser({}),
        'key "network_id" not in dict',
    )

    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser({"network_id": None}),
        'key "rpc_kind" not in dict',
    )

    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser({"network_id": None, "rpc_kind": None}),
        'key "el_rpc_url" not in dict',
    )

    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser({"network_id": None, "rpc_kind": None, "el_rpc_url": None}),
        'key "el_ws_url" not in dict',
    )

    expect.fails(
        lambda: _input_parser.external_l1_network_params_input_parser(
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
        lambda: _input_parser.external_l1_network_params_input_parser(
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


def test_external_l1_network_params_input_parser_set_fields(_plan):
    params = {
        "network_id": "network_id",
        "rpc_kind": "rpc_kind",
        "el_rpc_url": "el_rpc_url",
        "el_ws_url": "el_ws_url",
        "cl_rpc_url": "cl_rpc_url",
        "priv_key": "priv_key",
    }
    parsed_params = _input_parser.external_l1_network_params_input_parser(params)

    expect.eq(parsed_params, struct(**params))
