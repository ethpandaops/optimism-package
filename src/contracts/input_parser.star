_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_SAFES_ARGS = {
    "enabled": False,
    "image": None,
    "roles": {},
}


_DEFAULT_ARGS = {
    "image": None,
    "l1_artifacts_locator": None,
    "l2_artifacts_locator": None,
    "overrides": {},
    "safes": _DEFAULT_SAFES_ARGS,
}


def parse(args, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in op-deployer configuration: {}",
    )

    op_deployer_params = _DEFAULT_ARGS | _filter.remove_none(args or {})

    op_deployer_params["image"] = op_deployer_params["image"] or registry.get(
        _registry.OP_DEPLOYER
    )

    op_deployer_params["l1_artifacts_locator"] = op_deployer_params[
        "l1_artifacts_locator"
    ] or registry.get(_registry.OP_CONTRACTS)

    op_deployer_params["l2_artifacts_locator"] = op_deployer_params[
        "l2_artifacts_locator"
    ] or registry.get(_registry.OP_CONTRACTS)

    _validate_overrides(op_deployer_params["overrides"])

    op_deployer_params["safes"] = _parse_safes(op_deployer_params["safes"], registry)

    return struct(**op_deployer_params)


def _validate_overrides(overrides):
    if type(overrides) != "dict":
        fail("overrides must be a dict, got {}".format(type(overrides)))

    for key, value in overrides.items():
        if type(value) != "string":
            fail("overrides must be a dict of strings, got {}".format(type(overrides)))


def _parse_safes(safes, registry):
    safes = _validate_safes(safes)

    if safes["enabled"]:
        safes["image"] = safes["image"] or registry.get(_registry.SAFE_UTILS)

    return struct(**safes)


def _validate_safes(safes):
    _filter.assert_keys(
        safes or {},
        _DEFAULT_SAFES_ARGS.keys(),
        "Invalid attributes in safes configuration: {}",
    )

    safes = _DEFAULT_SAFES_ARGS | _filter.remove_none(safes or {})

    roles = safes["roles"]
    if type(roles) != "dict":
        fail("safes.roles must be a dict, got {}".format(type(roles)))

    for name, spec in roles.items():
        if type(spec) != "string":
            fail("safes.roles must be a dict of strings, got {}".format(type(roles)))

        parts = spec.split(":")
        if len(parts) != 2:
            fail("Invalid safes.roles spec for {}: {}".format(name, spec))

        threshold = int(parts[0])
        num_owners = int(parts[1])
        if num_owners < threshold:
            fail(
                "safes.roles must have at least as many owners as the threshold for {}".format(
                    name
                )
            )

    return safes
