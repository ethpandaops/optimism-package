_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")
_id = import_module("/src/util/id.star")

_DEFAULT_ARGS = {
    "image": None,
    "enabled": True,
    "extra_params": [],
    "pprof_enabled": False,
}

def parse(args, registry):
    return _filter.remove_none(
        [
            _parse_instance(
                test_sequencer_args or {}, test_sequencer_name, registry
            )
            for test_sequencer_name, test_sequencer_args in (args or {}).items()
        ]
    )


def _parse_instance(test_sequencer_args, test_sequencer_name, registry):
    # Any extra attributes will cause an error
#     _filter.assert_keys(
#         test_sequencer_args or {},
#         _DEFAULT_ARGS.keys(),
#         "Invalid attributes in test sequencer configuration",
#     )

    _id.assert_id(test_sequencer_name)

    # We filter the None values so that we can merge dicts easily
    test_sequencer_params = _DEFAULT_ARGS | _filter.remove_none(test_sequencer_args or {})

    if not test_sequencer_params["enabled"]:
        return None

    # And default the image to the one in the registry
    test_sequencer_params["image"] = test_sequencer_params["image"] or registry.get(
        _registry.OP_TEST_SEQUENCER
    )

    test_sequencer_params["name"] =  test_sequencer_name

    # Add the service name
    test_sequencer_params["service_name"] = "op-test-sequencer-{}".format(
        test_sequencer_name
    )

    # Add ports
    test_sequencer_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(number=8545),
    }

    # Add labels
    test_sequencer_params["labels"] = {
        "op.kind": "test-sequencer",
    }

    return struct(**test_sequencer_params)
