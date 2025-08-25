_registry = import_module("/src/package_io/registry.star")
_el_input_parser = import_module("/src/el/input_parser.star")


def parse(el_args, network_params, registry):
    if not el_args:
        return None

    if not el_args.get("image"):
        el_args["image"] = registry.get(_registry.FLASHBLOCKS_RPC)

    # TODO(#979): We should check whether any participant has the same name
    parsed = _el_input_parser.parse(
        el_args=el_args,
        participant_name="flashblocks-rpc-do-not-use",
        participant_index=0,
        network_params=network_params,
        registry=registry,
    )

    return parsed
