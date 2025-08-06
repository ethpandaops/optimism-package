_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    "enabled": True,
    "extra_params": [],
    "pprof_enabled": False,
}


def parse(test_sequencer_args, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        test_sequencer_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in test sequencer configuration for " + network_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    test_sequencer_params = _DEFAULT_ARGS | _filter.remove_none(test_sequencer_args or {})

    if not test_sequencer_params["enabled"]:
        return None

    # And default the image to the one in the registry
    test_sequencer_params["image"] = test_sequencer_params["image"] or registry.get(
        _registry.OP_TEST_SEQUENCER
    )

    # Add the service name
    test_sequencer_params["service_name"] = "op-test-sequencer"

    # Add ports
    test_sequencer_params["ports"] = {
        _net.HTTP_PORT_NAME: _net.port(number=8545),
    }

    # Add labels
    test_sequencer_params["labels"] = {
        "op.kind": "test-sequencer",
    }

    return struct(**test_sequencer_params)
