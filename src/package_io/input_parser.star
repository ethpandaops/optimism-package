ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

_challenger_input_parser = import_module("/src/challenger/input_parser.star")
_superchain_input_parser = import_module("/src/superchain/input_parser.star")
_supervisor_input_parser = import_module("/src/supervisor/input_parser.star")

constants = import_module("../package_io/constants.star")
sanity_check = import_module("./sanity_check.star")
_registry = import_module("./registry.star")


DEFAULT_DA_SERVER_PARAMS = {
    "cmd": [
        "da-server",  # uses keccak commitments by default
        # We use the file storage backend instead of s3 for simplicity.
        # Blobs and commitments are stored in the /home directory (which already exists).
        # Note that this storage is ephemeral because we aren't mounting an external kurtosis file.
        # This means that the data is lost when the container is deleted.
        "--file.path=/home",
        "--addr=0.0.0.0",
        "--port=3100",
        "--log.level=debug",
    ],
}

DEFAULT_ADDITIONAL_SERVICES = []


def external_l1_network_params_input_parser(plan, input_args):
    sanity_check.external_l1_network_params_input_parser(plan, input_args)
    return struct(
        network_id=input_args["network_id"],
        rpc_kind=input_args["rpc_kind"],
        el_rpc_url=input_args["el_rpc_url"],
        el_ws_url=input_args["el_ws_url"],
        cl_rpc_url=input_args["cl_rpc_url"],
        priv_key=input_args["priv_key"],
    )


def input_parser(
    plan,
    input_args,
    registry=_registry.Registry(),
):
    sanity_check.sanity_check(plan, input_args)
    results = parse_network_params(plan, registry, input_args)

    return struct(
        observability=struct(
            enabled=results["observability"]["enabled"],
            enable_k8s_features=results["observability"]["enable_k8s_features"],
            prometheus_params=struct(
                image=results["observability"]["prometheus_params"]["image"],
                storage_tsdb_retention_time=results["observability"][
                    "prometheus_params"
                ]["storage_tsdb_retention_time"],
                storage_tsdb_retention_size=results["observability"][
                    "prometheus_params"
                ]["storage_tsdb_retention_size"],
                min_cpu=results["observability"]["prometheus_params"]["min_cpu"],
                max_cpu=results["observability"]["prometheus_params"]["max_cpu"],
                min_mem=results["observability"]["prometheus_params"]["min_mem"],
                max_mem=results["observability"]["prometheus_params"]["max_mem"],
            ),
            loki_params=struct(
                image=results["observability"]["loki_params"]["image"],
                min_cpu=results["observability"]["loki_params"]["min_cpu"],
                max_cpu=results["observability"]["loki_params"]["max_cpu"],
                min_mem=results["observability"]["loki_params"]["min_mem"],
                max_mem=results["observability"]["loki_params"]["max_mem"],
            ),
            promtail_params=struct(
                image=results["observability"]["promtail_params"]["image"],
                min_cpu=results["observability"]["promtail_params"]["min_cpu"],
                max_cpu=results["observability"]["promtail_params"]["max_cpu"],
                min_mem=results["observability"]["promtail_params"]["min_mem"],
                max_mem=results["observability"]["promtail_params"]["max_mem"],
            ),
            grafana_params=struct(
                image=results["observability"]["grafana_params"]["image"],
                dashboard_sources=results["observability"]["grafana_params"][
                    "dashboard_sources"
                ],
                min_cpu=results["observability"]["grafana_params"]["min_cpu"],
                max_cpu=results["observability"]["grafana_params"]["max_cpu"],
                min_mem=results["observability"]["grafana_params"]["min_mem"],
                max_mem=results["observability"]["grafana_params"]["max_mem"],
            ),
        ),
        faucet=struct(
            enabled=results["faucet"]["enabled"],
            image=results["faucet"]["image"],
        ),
        altda_deploy_config=struct(
            use_altda=results["altda_deploy_config"]["use_altda"],
            da_commitment_type=results["altda_deploy_config"]["da_commitment_type"],
            da_challenge_window=results["altda_deploy_config"]["da_challenge_window"],
            da_resolve_window=results["altda_deploy_config"]["da_resolve_window"],
            da_bond_size=results["altda_deploy_config"]["da_bond_size"],
            da_resolver_refund_percentage=results["altda_deploy_config"][
                "da_resolver_refund_percentage"
            ],
        ),
        chains=[
            struct(
                participants=[
                    struct(
                        el_type=participant["el_type"],
                        el_image=participant["el_image"],
                        el_log_level=participant["el_log_level"],
                        el_extra_env_vars=participant["el_extra_env_vars"],
                        el_extra_labels=participant["el_extra_labels"],
                        el_extra_params=participant["el_extra_params"],
                        el_tolerations=participant["el_tolerations"],
                        el_volume_size=participant["el_volume_size"],
                        el_min_cpu=participant["el_min_cpu"],
                        el_max_cpu=participant["el_max_cpu"],
                        el_min_mem=participant["el_min_mem"],
                        el_max_mem=participant["el_max_mem"],
                        cl_type=participant["cl_type"],
                        cl_image=participant["cl_image"],
                        cl_log_level=participant["cl_log_level"],
                        cl_extra_env_vars=participant["cl_extra_env_vars"],
                        cl_extra_labels=participant["cl_extra_labels"],
                        cl_extra_params=participant["cl_extra_params"],
                        cl_tolerations=participant["cl_tolerations"],
                        cl_volume_size=participant["cl_volume_size"],
                        cl_min_cpu=participant["cl_min_cpu"],
                        cl_max_cpu=participant["cl_max_cpu"],
                        cl_min_mem=participant["cl_min_mem"],
                        cl_max_mem=participant["cl_max_mem"],
                        el_builder_type=participant["el_builder_type"],
                        el_builder_image=participant["el_builder_image"],
                        el_builder_key=participant["el_builder_key"],
                        el_builder_log_level=participant["el_builder_log_level"],
                        el_builder_extra_env_vars=participant[
                            "el_builder_extra_env_vars"
                        ],
                        el_builder_extra_labels=participant["el_builder_extra_labels"],
                        el_builder_extra_params=participant["el_builder_extra_params"],
                        el_builder_tolerations=participant["el_builder_tolerations"],
                        el_builder_volume_size=participant["el_builder_volume_size"],
                        el_builder_min_cpu=participant["el_builder_min_cpu"],
                        el_builder_max_cpu=participant["el_builder_max_cpu"],
                        el_builder_min_mem=participant["el_builder_min_mem"],
                        el_builder_max_mem=participant["el_builder_max_mem"],
                        cl_builder_type=participant["cl_builder_type"],
                        cl_builder_image=participant["cl_builder_image"],
                        cl_builder_log_level=participant["cl_builder_log_level"],
                        cl_builder_extra_env_vars=participant[
                            "cl_builder_extra_env_vars"
                        ],
                        cl_builder_extra_labels=participant["cl_builder_extra_labels"],
                        cl_builder_extra_params=participant["cl_builder_extra_params"],
                        cl_builder_tolerations=participant["cl_builder_tolerations"],
                        cl_builder_volume_size=participant["cl_builder_volume_size"],
                        cl_builder_min_cpu=participant["cl_builder_min_cpu"],
                        cl_builder_max_cpu=participant["cl_builder_max_cpu"],
                        cl_builder_min_mem=participant["cl_builder_min_mem"],
                        cl_builder_max_mem=participant["cl_builder_max_mem"],
                        node_selectors=participant["node_selectors"],
                        tolerations=participant["tolerations"],
                        count=participant["count"],
                    )
                    for participant in result["participants"]
                ],
                network_params=struct(
                    network=result["network_params"]["network"],
                    network_id=result["network_params"]["network_id"],
                    seconds_per_slot=result["network_params"]["seconds_per_slot"],
                    name=result["network_params"]["name"],
                    fjord_time_offset=result["network_params"]["fjord_time_offset"],
                    granite_time_offset=result["network_params"]["granite_time_offset"],
                    holocene_time_offset=result["network_params"][
                        "holocene_time_offset"
                    ],
                    isthmus_time_offset=result["network_params"]["isthmus_time_offset"],
                    interop_time_offset=result["network_params"]["interop_time_offset"],
                    fund_dev_accounts=result["network_params"]["fund_dev_accounts"],
                ),
                proxyd_params=struct(
                    image=result["proxyd_params"]["image"],
                    extra_params=result["proxyd_params"]["extra_params"],
                ),
                batcher_params=struct(
                    image=result["batcher_params"]["image"],
                    extra_params=result["batcher_params"]["extra_params"],
                ),
                proposer_params=struct(
                    image=result["proposer_params"]["image"],
                    extra_params=result["proposer_params"]["extra_params"],
                    game_type=result["proposer_params"]["game_type"],
                    proposal_interval=result["proposer_params"]["proposal_interval"],
                ),
                mev_params=struct(
                    rollup_boost_image=result["mev_params"]["rollup_boost_image"],
                    builder_host=result["mev_params"]["builder_host"],
                    builder_port=result["mev_params"]["builder_port"],
                ),
                da_server_params=struct(
                    enabled=result["da_server_params"]["enabled"],
                    image=result["da_server_params"]["image"],
                    cmd=result["da_server_params"]["cmd"],
                ),
                additional_services=result["additional_services"],
                tx_fuzzer_params=struct(
                    image=result["tx_fuzzer_params"]["image"],
                    tx_fuzzer_extra_args=result["tx_fuzzer_params"][
                        "tx_fuzzer_extra_args"
                    ],
                ),
            )
            for result in results["chains"]
        ],
        challengers=results["challengers"],
        superchains=results["superchains"],
        supervisors=results["supervisors"],
        op_contract_deployer_params=struct(
            image=results["op_contract_deployer_params"]["image"],
            l1_artifacts_locator=results["op_contract_deployer_params"][
                "l1_artifacts_locator"
            ],
            l2_artifacts_locator=results["op_contract_deployer_params"][
                "l2_artifacts_locator"
            ],
            overrides=results["op_contract_deployer_params"]["overrides"],
        ),
        global_log_level=results["global_log_level"],
        global_node_selectors=results["global_node_selectors"],
        global_tolerations=results["global_tolerations"],
        persistent=results["persistent"],
    )


def parse_network_params(plan, registry, input_args):
    results = {}

    # configure observability

    results["observability"] = default_observability_params()
    results["observability"].update(input_args.get("observability", {}))

    results["faucet"] = _default_faucet_params(registry)
    results["faucet"].update(input_args.get("faucet", {}))

    results["observability"]["prometheus_params"] = default_prometheus_params(registry)
    results["observability"]["prometheus_params"].update(
        input_args.get("observability", {}).get("prometheus_params", {})
    )

    results["observability"]["loki_params"] = default_loki_params(registry)
    results["observability"]["loki_params"].update(
        input_args.get("observability", {}).get("loki_params", {})
    )

    results["observability"]["promtail_params"] = default_promtail_params(registry)
    results["observability"]["promtail_params"].update(
        input_args.get("observability", {}).get("promtail_params", {})
    )

    results["observability"]["grafana_params"] = default_grafana_params(registry)
    results["observability"]["grafana_params"].update(
        input_args.get("observability", {}).get("grafana_params", {})
    )

    # configure altda

    results["altda_deploy_config"] = default_altda_deploy_config()
    results["altda_deploy_config"].update(input_args.get("altda_deploy_config", {}))

    # configure chains

    chains = []

    seen_names = {}
    seen_network_ids = {}
    for chain in input_args.get("chains", default_chains(registry)):
        network_params = default_network_params()
        network_params.update(chain.get("network_params", {}))

        proxyd_params = _default_proxyd_params(registry)
        proxyd_params.update(chain.get("proxyd_params", {}))

        batcher_params = _default_batcher_params(registry)
        batcher_params.update(chain.get("batcher_params", {}))

        proposer_params = _default_proposer_params(registry)
        proposer_params.update(chain.get("proposer_params", {}))

        mev_params = default_mev_params()
        mev_params.update(chain.get("mev_params", {}))
        da_server_params = default_da_server_params(registry)
        da_server_params.update(chain.get("da_server_params", {}))

        network_name = network_params["name"]
        network_id = network_params["network_id"]

        if network_name in seen_names:
            fail("Network name {0} is duplicated".format(network_name))

        if network_id in seen_network_ids:
            fail("Network id {0} is duplicated".format(network_id))

        participants = []
        for i, p in enumerate(chain.get("participants", [default_participant()])):
            participant = default_participant()
            participant.update(p)

            el_type = participant["el_type"]
            cl_type = participant["cl_type"]
            el_image = participant["el_image"]
            if el_image == "":
                default_image = registry.get(el_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            el_type
                        )
                    )
                participant["el_image"] = default_image

            cl_image = participant["cl_image"]
            if cl_image == "":
                default_image = registry.get(cl_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            cl_type
                        )
                    )
                participant["cl_image"] = default_image

            el_builder_type = participant["el_builder_type"]
            el_builder_image = participant["el_builder_image"]
            if el_builder_image == "":
                default_image = registry.get(el_builder_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            el_builder_type
                        )
                    )
                participant["el_builder_image"] = default_image

            cl_builder_type = participant["cl_builder_type"]
            cl_builder_image = participant["cl_builder_image"]
            if cl_builder_image == "":
                default_image = registry.get(cl_builder_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            cl_builder_type
                        )
                    )
                participant["cl_builder_image"] = default_image

            for _ in range(0, participant["count"]):
                participant_copy = ethereum_package_input_parser.deep_copy_participant(
                    participant
                )
                participants.append(participant_copy)

        tx_fuzzer_params = default_tx_fuzzer_params(registry)
        tx_fuzzer_params.update(chain.get("tx_fuzzer_params", {}))

        result = {
            "participants": participants,
            "network_params": network_params,
            "proxyd_params": proxyd_params,
            "batcher_params": batcher_params,
            "proposer_params": proposer_params,
            "mev_params": mev_params,
            "da_server_params": da_server_params,
            "additional_services": chain.get(
                "additional_services", DEFAULT_ADDITIONAL_SERVICES
            ),
            "tx_fuzzer_params": tx_fuzzer_params,
        }
        chains.append(result)

    results["chains"] = chains

    # configure superchains

    results["superchains"] = _superchain_input_parser.parse(
        args=input_args.get("superchains"), chains=chains
    )

    # configure op-challenger

    results["challengers"] = _challenger_input_parser.parse(
        args=input_args.get("challengers"), chains=chains
    )

    # configure op-supervisor

    results["supervisors"] = _supervisor_input_parser.parse(
        args=input_args.get("supervisors"),
        superchains=results["superchains"],
        registry=registry,
    )

    # configure op-deployer

    results["op_contract_deployer_params"] = default_op_contract_deployer_params(
        registry
    )
    results["op_contract_deployer_params"].update(
        input_args.get("op_contract_deployer_params", {})
    )

    # configure global args

    results["global_log_level"] = "info"
    results["global_node_selectors"] = {}
    results["global_tolerations"] = []
    results["persistent"] = False

    results["global_log_level"] = input_args.get("global_log_level", "info")
    results["global_node_selectors"].update(input_args.get("global_node_selectors", {}))
    results["global_tolerations"] = input_args.get("global_tolerations", [])
    results["persistent"] = input_args.get("persistent", False)

    return results


def default_observability_params():
    return {
        "enabled": True,
        "enable_k8s_features": False,
    }


def _default_faucet_params(registry):
    return {
        "enabled": False,
        "image": registry.get(_registry.OP_FAUCET),
    }


def default_prometheus_params(registry):
    return {
        "image": registry.get(_registry.PROMETHEUS),
        "storage_tsdb_retention_time": "1d",
        "storage_tsdb_retention_size": "512MB",
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_grafana_params(registry):
    return {
        "image": registry.get(_registry.GRAFANA),
        "dashboard_sources": [
            "github.com/ethereum-optimism/grafana-dashboards-public/resources"
        ],
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_loki_params(registry):
    return {
        "image": registry.get(_registry.LOKI),
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_promtail_params(registry):
    return {
        "image": registry.get(_registry.PROMTAIL),
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_altda_deploy_config():
    return {
        "use_altda": False,
        "da_commitment_type": "KeccakCommitment",
        "da_challenge_window": 100,
        "da_resolve_window": 100,
        "da_bond_size": 0,
        "da_resolver_refund_percentage": 0,
    }


def default_mev_params():
    return {
        "rollup_boost_image": "",
        "builder_host": "",
        "builder_port": "",
    }


def default_chains(registry):
    return [
        {
            "participants": [default_participant()],
            "network_params": default_network_params(),
            "proxyd_params": _default_proxyd_params(registry),
            "batcher_params": _default_batcher_params(registry),
            "proposer_params": _default_proposer_params(registry),
            "mev_params": default_mev_params(),
            "da_server_params": default_da_server_params(registry),
            "additional_services": DEFAULT_ADDITIONAL_SERVICES,
            "tx_fuzzer_params": default_tx_fuzzer_params(registry),
        }
    ]


def default_network_params():
    return {
        "network": constants.NETWORK_NAME,
        "network_id": "2151908",
        "name": "op-kurtosis",
        "seconds_per_slot": 2,
        "fjord_time_offset": 0,
        "granite_time_offset": 0,
        "holocene_time_offset": None,
        "isthmus_time_offset": None,
        "interop_time_offset": None,
        "fund_dev_accounts": True,
    }


def _default_batcher_params(registry):
    return {
        "image": registry.get(_registry.OP_BATCHER),
        "extra_params": [],
    }


def _default_proxyd_params(registry):
    return {
        "image": registry.get(_registry.PROXYD),
        "extra_params": [],
    }


def _default_proposer_params(registry):
    return {
        "image": registry.get(_registry.OP_PROPOSER),
        "extra_params": [],
        "game_type": 1,
        "proposal_interval": "10m",
    }


def default_participant():
    return {
        "el_type": "op-geth",
        "el_image": "",
        "el_log_level": "",
        "el_extra_env_vars": {},
        "el_extra_labels": {},
        "el_extra_params": [],
        "el_tolerations": [],
        "el_volume_size": 0,
        "el_min_cpu": 0,
        "el_max_cpu": 0,
        "el_min_mem": 0,
        "el_max_mem": 0,
        "cl_type": "op-node",
        "cl_image": "",
        "cl_log_level": "",
        "cl_extra_env_vars": {},
        "cl_extra_labels": {},
        "cl_extra_params": [],
        "cl_tolerations": [],
        "cl_volume_size": 0,
        "cl_min_cpu": 0,
        "cl_max_cpu": 0,
        "cl_min_mem": 0,
        "cl_max_mem": 0,
        "el_builder_type": "op-geth",
        "el_builder_image": "",
        "el_builder_key": "",
        "el_builder_log_level": "",
        "el_builder_extra_env_vars": {},
        "el_builder_extra_labels": {},
        "el_builder_extra_params": [],
        "el_builder_tolerations": [],
        "el_builder_volume_size": 0,
        "el_builder_min_cpu": 0,
        "el_builder_max_cpu": 0,
        "el_builder_min_mem": 0,
        "el_builder_max_mem": 0,
        "cl_builder_type": "op-node",
        "cl_builder_image": "",
        "cl_builder_log_level": "",
        "cl_builder_extra_env_vars": {},
        "cl_builder_extra_labels": {},
        "cl_builder_extra_params": [],
        "cl_builder_tolerations": [],
        "cl_builder_volume_size": 0,
        "cl_builder_min_cpu": 0,
        "cl_builder_max_cpu": 0,
        "cl_builder_min_mem": 0,
        "cl_builder_max_mem": 0,
        "node_selectors": {},
        "tolerations": [],
        "count": 1,
    }


def default_op_contract_deployer_params(registry):
    return {
        "image": registry.get(_registry.OP_DEPLOYER),
        "l1_artifacts_locator": "https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-02024c5a26c16fc1a5c716fff1c46b5bf7f23890d431bb554ddbad60971211d4.tar.gz",
        "l2_artifacts_locator": "https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-02024c5a26c16fc1a5c716fff1c46b5bf7f23890d431bb554ddbad60971211d4.tar.gz",
        "overrides": {},
    }


def default_ethereum_package_network_params():
    return {
        "participants": [
            {
                "el_type": "geth",
                "cl_type": "lighthouse",
            }
        ],
        "network_params": {
            "preset": "minimal",
            "genesis_delay": 5,
            # Preload the Arachnid CREATE2 deployer
            "additional_preloaded_contracts": json.encode(
                {
                    "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
                        "balance": "0ETH",
                        "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
                        "storage": {},
                        "nonce": "1",
                    }
                }
            ),
        },
    }


def default_da_server_params(registry):
    return {
        "enabled": False,
        "image": registry.get(_registry.DA_SERVER),
        "cmd": DEFAULT_DA_SERVER_PARAMS["cmd"],
    }


def default_tx_fuzzer_params(registry):
    return {
        "image": registry.get(_registry.TX_FUZZER),
        "tx_fuzzer_extra_args": [],
    }
