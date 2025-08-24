_filter = import_module("/src/util/filter.star")
_id = import_module("/src/util/id.star")

_l2_participant_input_parser = import_module("./participant/input_parser.star")
_batcher_input_parser = import_module("/src/batcher/input_parser.star")
_blockscout_input_parser = import_module("/src/blockscout/input_parser.star")
_da_input_parser = import_module("/src/da/input_parser.star")
_proposer_input_parser = import_module("/src/proposer/input_parser.star")
_proxyd_input_parser = import_module("/src/proxyd/input_parser.star")
_signer_input_parser = import_module("/src/signer/input_parser.star")
_tx_fuzzer_input_parser = import_module("/src/tx-fuzzer/input_parser.star")
_flashblocks_input_parser = import_module("/src/flashblocks/input_parser.star")
_el_input_parser = import_module("/src/el/input_parser.star")
_registry = import_module("/src/package_io/registry.star")

_DEFAULT_NETWORK_PARAMS = {
    "network": "kurtosis",
    "network_id": None,
    "seconds_per_slot": 2,
    "fjord_time_offset": 0,
    "granite_time_offset": 0,
    "holocene_time_offset": None,
    "isthmus_time_offset": None,
    "jovian_time_offset": None,
    "interop_time_offset": None,
    "fund_dev_accounts": True,
}

_DEFAULT_ARGS = {
    "participants": {},
    "network_params": _DEFAULT_NETWORK_PARAMS,
    "da_params": None,
    "proposer_params": None,
    "batcher_params": None,
    "blockscout_params": None,
    "signer_params": None,
    "proxyd_params": None,
    "tx_fuzzer_params": None,
    "flashblocks_websocket_proxy_params": None,
    "flashblocks_rpc_params": None,
}


def parse(args, registry):
    l2_id_generator = _id.autoincrement(2151908)

    return _assert_unique_l2_ids(
        _filter.remove_none(
            [
                _parse_instance(
                    l2_args
                    or {
                        # If we get empty L2 args, we supply some defaults so that we get at least one participant
                        "participants": {
                            "node0": None,
                        }
                    },
                    l2_name,
                    l2_id_generator,
                    registry,
                )
                for l2_name, l2_args in (
                    args
                    or {
                        # If we get no networks, we supply a default one
                        "opkurtosis": None,
                    }
                ).items()
            ]
        )
    )


def _assert_unique_l2_ids(l2s_params):
    l2_ids = [l2_params.network_params.network_id for l2_params in l2s_params]
    duplicated_l2_ids = _filter.get_duplicates(l2_ids)
    if duplicated_l2_ids:
        fail(
            "L2 IDs must be unique, got duplicates: {}".format(
                ",".join([str(id) for id in duplicated_l2_ids])
            )
        )

    return l2s_params


def _parse_instance(l2_args, l2_name, l2_id_generator, registry):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        l2_args or {},
        _DEFAULT_ARGS.keys(),
        "Invalid attributes in L2 configuration for " + l2_name + ": {}",
    )

    # We make sure the L2 name is a valid name
    _id.assert_id(id=l2_name, name="L2 name")

    # We filter the None values so that we can merge dicts easily
    l2_params = _DEFAULT_ARGS | _filter.remove_none(l2_args or {})

    # We parse the network params
    l2_params["network_params"] = _parse_network_params(
        l2_params["network_params"], l2_name, l2_id_generator
    )

    l2_params["participants"] = _l2_participant_input_parser.parse(
        l2_params["participants"], l2_params["network_params"], registry
    )

    # We add the proposer params
    l2_params["proposer_params"] = _proposer_input_parser.parse(
        l2_params["proposer_params"], l2_params["network_params"], registry
    )

    # We add the batcher params
    l2_params["batcher_params"] = _batcher_input_parser.parse(
        l2_params["batcher_params"], l2_params["network_params"], registry
    )

    # We add the proxyd params
    l2_params["proxyd_params"] = _proxyd_input_parser.parse(
        proxyd_args=l2_params["proxyd_params"],
        network_params=l2_params["network_params"],
        participants_params=l2_params["participants"],
        registry=registry,
    )

    # We add the signer params
    l2_params["signer_params"] = _signer_input_parser.parse(
        signer_args=l2_params["signer_params"],
        network_params=l2_params["network_params"],
        registry=registry,
    )

    # We add the tx-fuzzer params
    l2_params["tx_fuzzer_params"] = _tx_fuzzer_input_parser.parse(
        tx_fuzzer_args=l2_params["tx_fuzzer_params"],
        network_params=l2_params["network_params"],
        registry=registry,
    )

    # We add the DA params
    l2_params["da_params"] = _da_input_parser.parse(
        da_args=l2_params["da_params"],
        network_params=l2_params["network_params"],
        registry=registry,
    )

    # We add the explorer params
    l2_params["blockscout_params"] = _blockscout_input_parser.parse(
        blockscout_args=l2_params["blockscout_params"],
        network_params=l2_params["network_params"],
        registry=registry,
    )

    # We add the flashblocks params
    l2_params["flashblocks_websocket_proxy_params"] = _flashblocks_input_parser.parse(
        websocket_proxy_args=l2_params["flashblocks_websocket_proxy_params"],
        network_params=l2_params["network_params"],
        registry=registry,
    )

    # WARNING: We can't have another participant with the same name
    # TODO: We should check whether any participant has the same name
    # as the flashblocks RPC participant and fail if so
    # Add the image if it's not already set
    if l2_params["flashblocks_rpc_params"]:
        if not l2_params["flashblocks_rpc_params"].get("image"):
            l2_params["flashblocks_rpc_params"]["image"] = registry.get(
                _registry.FLASHBLOCKS_RPC
            )
        l2_params["flashblocks_rpc_params"] = _el_input_parser.parse(
            el_args=l2_params["flashblocks_rpc_params"],
            participant_name="flashblocks-rpc-do-not-use",
            participant_index=0,
            network_params=l2_params["network_params"],
            registry=registry,
        )

    return struct(
        **l2_params,
    )


def _assert_l2_id(l2_id):
    if type(l2_id) == "int":
        return l2_id

    if type(l2_id) == "string":
        if l2_id.isdigit():
            return int(l2_id)

    fail("L2 ID must be a positive integer in decimal base, got {}".format(l2_id))


def _parse_network_params(network_args, l2_name, l2_id_generator):
    # Any extra attributes will cause an error
    _filter.assert_keys(
        network_args or {},
        _DEFAULT_NETWORK_PARAMS.keys(),
        "Invalid attributes in L2 network_params for " + l2_name + ": {}",
    )

    # We filter the None values so that we can merge dicts easily
    network_params = _DEFAULT_NETWORK_PARAMS | _filter.remove_none(network_args or {})

    # We make sure the network_id is a valid id if provided, if not we supply a default one
    network_params["network_id"] = (
        _assert_l2_id(network_params["network_id"])
        if network_params["network_id"]
        else l2_id_generator()
    )

    # We add the network name to params
    network_params["name"] = l2_name

    return struct(**network_params)
