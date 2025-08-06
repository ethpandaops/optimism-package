ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

_ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

_batcher_input_parser = import_module("/src/batcher/input_parser.star")
_blockscout_input_parser = import_module("/src/blockscout/input_parser.star")
_da_input_parser = import_module("/src/da/input_parser.star")
_challenger_input_parser = import_module("/src/challenger/input_parser.star")
_l2_input_parser = import_module("/src/l2/input_parser.star")
_mev_input_parser = import_module("/src/mev/input_parser.star")
_superchain_input_parser = import_module("/src/superchain/input_parser.star")
_proposer_input_parser = import_module("/src/proposer/input_parser.star")
_proxyd_input_parser = import_module("/src/proxyd/input_parser.star")
_supervisor_input_parser = import_module("/src/supervisor/input_parser.star")
_tx_fuzzer_parser = import_module("/src/tx-fuzzer/input_parser.star")
_interop_mon_input_parser = import_module("/src/interop-mon/input_parser.star")
_test_sequencer_input_parser = import_module("/src/test-sequencer/input_parser.star")

constants = import_module("../package_io/constants.star")
sanity_check = import_module("./sanity_check.star")
_registry = import_module("./registry.star")

_net = import_module("/src/util/net.star")


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
        interop_mon=results["interop_mon"],
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
        chains=results["chains"],
        challengers=results["challengers"],
        superchains=results["superchains"],
        supervisors=results["supervisors"],
        test_sequencers=results["test_sequencers"],
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
    network_params = default_network_params()

    # configure observability

    results["observability"] = default_observability_params()
    results["observability"].update(input_args.get("observability", {}))

    results["faucet"] = _default_faucet_params(registry)
    results["faucet"].update(input_args.get("faucet", {}))

    results["interop_mon"] = _interop_mon_input_parser.parse(
        args=input_args.get("interop_mon", {}),
        network_params=struct(**network_params),
        registry=registry,
    )

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

    results["chains"] = _l2_input_parser.parse(
        args=input_args.get("chains"), registry=registry
    )

    # configure superchains

    results["superchains"] = _superchain_input_parser.parse(
        args=input_args.get("superchains"), l2s_params=results["chains"]
    )

    # configure op-challenger

    results["challengers"] = _challenger_input_parser.parse(
        args=input_args.get("challengers"), l2s_params=results["chains"]
    )

    # configure op-supervisor

    results["supervisors"] = _supervisor_input_parser.parse(
        args=input_args.get("supervisors"),
        superchains=results["superchains"],
        registry=registry,
    )

    # configure op-test-sequencer

    results["test_sequencer"] = _test_sequencer_input_parser(
        args=input_args.get("test_sequencer"),
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
            "github.com/ethereum-optimism/grafana-dashboards-public/resources",
            "github.com/op-rs/kona/docker/recipes/kona-node/grafana",
            "github.com/paradigmxyz/reth/etc/grafana",
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
        "image": "",
        "type": "rollup-boost",
        "builder_host": "",
        "builder_port": "",
    }


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
        "jovian_time_offset": None,
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
    }


def default_tx_fuzzer_params(registry):
    return {
        "enabled": False,
        "image": registry.get(_registry.TX_FUZZER),
        "extra_params": [],
        "min_cpu": 100,
        "max_cpu": 1000,
        "min_memory": 20,
        "max_memory": 300,
    }
