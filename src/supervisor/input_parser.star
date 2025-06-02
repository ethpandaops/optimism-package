_filter = import_module("/src/util/filter.star")
_net = import_module("/src/util/net.star")
_id = import_module("/src/util/id.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_ARGS = {
    "type": "op-supervisor",
    "enabled": True,
    "superchain": None,
    "image": None,
    "extra_params": [],
}

_IMAGE_IDS = {
    "op-supervisor": _registry.OP_SUPERVISOR,
    "kona-supervisor": _registry.KONA_SUPERVISOR,
}

def parse(args, superchains, registry):
    return _filter.remove_none(
        [
            _parse_instance(
                supervisor_args or {}, supervisor_name, superchains, registry
            )
            for supervisor_name, supervisor_args in (args or {}).items()
        ]
    )


def _parse_instance(supervisor_args, supervisor_name, superchains, registry):
    # Any extra attributes will cause an error
    extra_keys = _filter.assert_keys(
        supervisor_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in supervisor configuration for "
        + supervisor_name
        + ": {}",
    )

    _id.assert_id(supervisor_name)

    supervisor_params = _DEFAULT_ARGS | _filter.remove_none(supervisor_args or {})

    if not supervisor_params["enabled"]:
        return None

    # Let's find the superchain that this supervisor is connected to
    superchain_name = supervisor_params["superchain"]
    if not superchain_name:
        fail("Missing superchain name for supervisor {}".format(supervisor_name))

    superchain = _filter.first(superchains, lambda s: s.name == superchain_name)
    if not superchain:
        fail(
            "Missing superchain {} for supervisor {}".format(
                superchain_name, supervisor_name
            )
        )

    # We expand the superchain name to the full object for easier access
    #
    # The tradeoff that we are making is the duplication of information
    # in the parsed config, but this is a tradeoff that we are willing to make
    supervisor_params["superchain"] = superchain

    # And default the image to the one in the registry
    supervisor_params["image"] = supervisor_params["image"] or _default_image(
        supervisor_params["type"], registry
    )

    # We add name & service name
    supervisor_params["name"] = supervisor_name
    supervisor_params["service_name"] = "{}-{}-{}".format(
        supervisor_params["type"],
        supervisor_name,
        superchain_name,
    )

    # We'll also define the ports that this supervisor will expose
    #
    # This is so that we can reference them before the service is created
    supervisor_params["ports"] = {
        _net.RPC_PORT_NAME: _net.port(
            number=8545,
        )
    }

    return struct(**supervisor_params)


def _default_image(participant_type, registry):
    if participant_type in _IMAGE_IDS:
        return registry.get(_IMAGE_IDS[participant_type])
    else:
        fail("Invalid supervisor type: {}".format(participant_type))
