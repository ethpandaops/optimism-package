_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "image": None,
    "l1_artifacts_locator": None,
    "l2_artifacts_locator": None,
    "overrides": {},
    "multisig": {},
}


def parse(args, registry):
    # Any extra attributes will cause an error
    extra_keys = _filter.assert_keys(
        args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in op-deployer configuration: {}",
    )

    op_deployer_params = _DEFAULT_ARGS | _filter.remove_none(args or {})

    op_deployer_params["image"] = op_deployer_params["image"] or registry.get(
        _registry.OP_DEPLOYER
    )

    op_deployer_params["l1_artifacts_locator"] = op_deployer_params["l1_artifacts_locator"] or registry.get(
        _registry.OP_CONTRACTS
    )

    op_deployer_params["l2_artifacts_locator"] = op_deployer_params["l2_artifacts_locator"] or registry.get(
        _registry.OP_CONTRACTS
    )

    _validate_string_map("overrides", op_deployer_params["overrides"])
    _validate_string_map("multisig", op_deployer_params["multisig"])

    return struct(**op_deployer_params)


def _validate_string_map(name, string_map):
    if type(string_map) != "dict":
        fail("{} must be a dict, got {}".format(name, type(string_map)))

    for key, value in string_map.items():
        if type(value) != "string":
            fail("{} must be a dict of strings, got {}".format(name, type(value)))
