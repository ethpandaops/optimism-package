ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

constants = import_module("./constants.star")
sanity_check = import_module("./sanity_check.star")
util = import_module("../util.star")

DEFAULT_EL_IMAGES = {
    "op-geth": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
    "op-reth": "ghcr.io/paradigmxyz/op-reth:latest",
    "op-erigon": "testinprod/op-erigon:latest",
    "op-nethermind": "nethermind/nethermind:latest",
    "op-besu": "ghcr.io/optimism-java/op-besu:latest",
    "op-rbuilder": "ghcr.io/flashbots/op-rbuilder:latest",
}

DEFAULT_CL_IMAGES = {
    "op-node": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
    "hildr": "ghcr.io/optimism-java/hildr:latest",
}

DEFAULT_BATCHER_IMAGES = {
    "op-batcher": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:develop",
}

DEFAULT_CHALLENGER_IMAGES = {
    "op-challenger": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-challenger:develop",
}

DEFAULT_SUPERVISOR_IMAGES = {
    "op-supervisor": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:develop",
}

DEFAULT_PROPOSER_IMAGES = {
    "op-proposer": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:develop",
}

DEFAULT_SIDECAR_IMAGES = {
    "rollup-boost": "flashbots/rollup-boost:latest",
}

DEFAULT_DA_SERVER_PARAMS = {
    "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/da-server:latest",
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

DEFAULT_TX_FUZZER_IMAGES = {
    "tx-fuzzer": "ethpandaops/tx-fuzz:master",
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


def input_parser(plan, input_args):
    sanity_check.sanity_check(plan, input_args)
    results = parse_network_params(plan, input_args)

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
        interop=struct(
            enabled=results["interop"]["enabled"],
            supervisor_params=struct(
                image=results["interop"]["supervisor_params"]["image"],
                dependency_set=results["interop"]["supervisor_params"][
                    "dependency_set"
                ],
                extra_params=results["interop"]["supervisor_params"]["extra_params"],
            ),
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
                    tag=result["proxyd_params"]["tag"],
                    extra_params=result["proxyd_params"]["extra_params"],
                ),
                batcher_params=struct(
                    image=result["batcher_params"]["image"],
                    extra_params=result["batcher_params"]["extra_params"],
                ),
                challenger_params=struct(
                    enabled=result["challenger_params"]["enabled"],
                    image=result["challenger_params"]["image"],
                    extra_params=result["challenger_params"]["extra_params"],
                    cannon_prestate_path=result["challenger_params"][
                        "cannon_prestate_path"
                    ],
                    cannon_prestates_url=result["challenger_params"][
                        "cannon_prestates_url"
                    ],
                    cannon_trace_types=result["challenger_params"][
                        "cannon_trace_types"
                    ],
                ),
                proposer_params=struct(
                    image=result["proposer_params"]["image"],
                    extra_params=result["proposer_params"]["extra_params"],
                    game_type=result["proposer_params"]["game_type"],
                    proposal_interval=result["proposer_params"]["proposal_interval"],
                ),
                signer_params=struct(
                    image=result["signer_params"]["image"],
                    tag=result["signer_params"]["tag"],
                    extra_params=result["signer_params"]["extra_params"],
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
        op_contract_deployer_params=struct(
            image=results["op_contract_deployer_params"]["image"],
            l1_artifacts_locator=results["op_contract_deployer_params"][
                "l1_artifacts_locator"
            ],
            l2_artifacts_locator=results["op_contract_deployer_params"][
                "l2_artifacts_locator"
            ],
            global_deploy_overrides=results["op_contract_deployer_params"][
                "global_deploy_overrides"
            ],
        ),
        global_log_level=results["global_log_level"],
        global_node_selectors=results["global_node_selectors"],
        global_tolerations=results["global_tolerations"],
        persistent=results["persistent"],
    )


def parse_network_params(plan, input_args):
    results = {}

    # configure observability

    results["observability"] = default_observability_params()
    results["observability"].update(input_args.get("observability", {}))

    results["observability"]["prometheus_params"] = default_prometheus_params()
    results["observability"]["prometheus_params"].update(
        input_args.get("observability", {}).get("prometheus_params", {})
    )

    results["observability"]["loki_params"] = default_loki_params()
    results["observability"]["loki_params"].update(
        input_args.get("observability", {}).get("loki_params", {})
    )

    results["observability"]["promtail_params"] = default_promtail_params()
    results["observability"]["promtail_params"].update(
        input_args.get("observability", {}).get("promtail_params", {})
    )

    results["observability"]["grafana_params"] = default_grafana_params()
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
    for chain in input_args.get("chains", default_chains()):
        network_params = default_network_params()
        network_params.update(chain.get("network_params", {}))

        proxyd_params = default_proxyd_params()
        proxyd_params.update(chain.get("proxyd_params", {}))

        batcher_params = default_batcher_params()
        batcher_params.update(chain.get("batcher_params", {}))

        proposer_params = default_proposer_params()
        proposer_params.update(chain.get("proposer_params", {}))

        challenger_params = default_challenger_params()
        challenger_params.update(chain.get("challenger_params", {}))

        signer_params = default_signer_params()
        signer_params.update(chain.get("signer_params", {}))

        mev_params = default_mev_params()
        mev_params.update(chain.get("mev_params", {}))

        da_server_params = default_da_server_params()
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
                default_image = DEFAULT_EL_IMAGES.get(el_type, "")
                if default_image == "":
                    fail(
                        "{0} received an empty image name and we don't have a default for it".format(
                            el_type
                        )
                    )
                participant["el_image"] = default_image

            cl_image = participant["cl_image"]
            if cl_image == "":
                default_image = DEFAULT_CL_IMAGES.get(cl_type, "")
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
                default_image = DEFAULT_EL_IMAGES.get(el_builder_type, "")
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
                default_image = DEFAULT_CL_IMAGES.get(cl_builder_type, "")
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

        tx_fuzzer_params = default_tx_fuzzer_params()
        tx_fuzzer_params.update(chain.get("tx_fuzzer_params", {}))

        result = {
            "participants": participants,
            "network_params": network_params,
            "proxyd_params": proxyd_params,
            "batcher_params": batcher_params,
            "challenger_params": challenger_params,
            "proposer_params": proposer_params,
            "signer_params": signer_params,
            "mev_params": mev_params,
            "da_server_params": da_server_params,
            "additional_services": chain.get(
                "additional_services", DEFAULT_ADDITIONAL_SERVICES
            ),
            "tx_fuzzer_params": tx_fuzzer_params,
        }
        chains.append(result)

    results["chains"] = chains

    # configure interop

    results["interop"] = build_interop_params(input_args.get("interop", {}), chains)

    # configure op-deployer

    results["op_contract_deployer_params"] = default_op_contract_deployer_params()
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


def default_prometheus_params():
    return {
        "image": "prom/prometheus:v3.1.0",
        "storage_tsdb_retention_time": "1d",
        "storage_tsdb_retention_size": "512MB",
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_grafana_params():
    return {
        "image": "grafana/grafana:11.5.0",
        "dashboard_sources": [
            "github.com/ethereum-optimism/grafana-dashboards-public/resources"
        ],
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_loki_params():
    return {
        "image": "grafana/loki:3.3.2",
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }


def default_promtail_params():
    return {
        "image": "grafana/promtail:3.3.2",
        "min_cpu": 10,
        "max_cpu": 1000,
        "min_mem": 128,
        "max_mem": 2048,
    }

def default_interop_params():
    return {
        "enabled": False,
        # Interop sets organize the networks into disconnected interop chain sets
        # 
        # If there are no sets defined, interop is effectively disabled.
        "sets": [],
        # Default values to apply for all interop sets' supervisors
        "supervisor_params": default_supervisor_params(),
    }

def default_supervisor_params():
    return {
        "image": DEFAULT_SUPERVISOR_IMAGES["op-supervisor"],
        "dependency_set": "",
        "extra_params": [],
    }

# This function normalizes the interop args to ensure that all values are set
def build_interop_params(interop_args, chains):
    # We first filter the None values so that we can merge dicts easily
    interop_args_without_none = util.filter_none(interop_args)

    # Then we build the sub-params
    supervisor_params = build_interop_supervisor_params(interop_args_without_none.get("supervisor_params", {}))
    sets_params = build_interop_sets_params(interop_args_without_none.get("sets", []), supervisor_params, chains)
    
    # If enabled is not explicitly set, we enable interop if there are any sets defined
    enabled_param = interop_args_without_none.get("enabled", len(sets_params) > 0)

    return {
        "enabled": enabled_param,
        "sets": sets_params,
        # This value is potentially no longer necessary here as all the interop sets
        # have their supervisor params set
        "supervisor_params": supervisor_params,
    }

# This function normalizes the interop supervisor_params args to ensure that all values are set
# 
# It is being used in two places:
# 
# - to build the default interop supervisor params, in which case the default values are the global defaults
# - to build the interop supervisor params for each interop set, in which case the default values are the interop supervisor params
def build_interop_supervisor_params(
    interop_supervisor_args,
    default_interop_supervisor_params = default_supervisor_params()
):
    interop_supervisor_args_without_none = util.filter_none(interop_supervisor_args)

    return {
        "image": interop_supervisor_args_without_none.get("image", default_interop_supervisor_params["image"]),
        "dependency_set": interop_supervisor_args_without_none.get("dependency_set", default_interop_supervisor_params["dependency_set"]),
        "extra_params": interop_supervisor_args_without_none.get("extra_params", default_interop_supervisor_params["extra_params"]),
    }

# This function normalizes the interop sets args to ensure that all values are set
def build_interop_sets_params(interop_sets_args, interop_supervisor_params, chains):
    interop_sets_params =  [
        build_interop_set_params(
            interop_set_args,
            interop_set_index,
            interop_supervisor_params,
            chains
        )
        for interop_set_index, interop_set_args in enumerate(interop_sets_args) if interop_set_args != None
    ]

    return interop_sets_params

# This function normalizes the interop sets args to ensure that all values are set
def build_interop_set_params(
    interop_set_args,
    # The suffix is used to create a default name for the interop set if no name is provided
    interop_set_suffix,
    interop_supervisor_params,
    chains
):
    interop_set_args_without_none = util.filter_none(interop_set_args)

    # Iterop set name is optional
    interop_set_name = interop_set_args_without_none.get("name", "interop-set-{}".format(interop_set_suffix))
    
    # Interop set participants can be specified as "*" to include all networks (default)
    # or as a list of network ids
    interop_set_participants = interop_set_args_without_none.get("participants", "*")
    expanded_interop_set_participants = expand_interop_set_participants(interop_set_participants, chains)

    # The interop set supervisor params are optional and default to the global interop supervisor params
    interop_set_supervisor_params = build_interop_supervisor_params(interop_set_args_without_none.get("supervisor_params", {}), interop_supervisor_params)

    return {
        "name": interop_set_name,
        "participants": expanded_interop_set_participants,
        "supervisor_params": interop_set_supervisor_params,
    }

def expand_interop_set_participants(interop_set_participants, chains):
    # kurtosis starlark doesn't support sets so we'll use a hashmap instead
    all_network_ids = {chain["network_params"]["network_id"]: True for chain in chains}

    # "*" is used as a shortcut to include all networks
    if interop_set_participants == "*":
        return all_network_ids.keys()
    elif type(interop_set_participants) == "list":
        # First we check that all the network IDs exist
        network_ids = [
            network_id if all_network_ids.get(network_id) else fail("Unknown network id in list of interop participants: {}".format(network_id)) for network_id in interop_set_participants
        ]

        # Then we make sure that there are no duplicates within one interop set
        duplicate_network_ids = util.get_duplicates(network_ids)
        if len(duplicate_network_ids) > 0:
            fail("Duplicate network ids in list of interop participants: {}".format(duplicate_network_ids))

        return network_ids
    else:
        fail("Invalid interop set participants: {}".format(interop_set_participants))


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


def default_chains():
    return [
        {
            "participants": [default_participant()],
            "network_params": default_network_params(),
            "proxyd_params": default_proxyd_params(),
            "batcher_params": default_batcher_params(),
            "proposer_params": default_proposer_params(),
            "challenger_params": default_challenger_params(),
            "signer_params": default_signer_params(),
            "mev_params": default_mev_params(),
            "da_server_params": default_da_server_params(),
            "additional_services": DEFAULT_ADDITIONAL_SERVICES,
            "tx_fuzzer_params": default_tx_fuzzer_params(),
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


def default_batcher_params():
    return {
        "image": DEFAULT_BATCHER_IMAGES["op-batcher"],
        "extra_params": [],
    }


def default_proxyd_params():
    return {
        "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd",
        "tag": "v4.14.2",
        "extra_params": [],
    }


def default_challenger_params():
    return {
        "enabled": True,
        "image": DEFAULT_CHALLENGER_IMAGES["op-challenger"],
        "extra_params": [],
        "cannon_prestate_path": "",
        "cannon_prestates_url": "https://storage.googleapis.com/oplabs-network-data/proofs/op-program/cannon",
        "cannon_trace_types": ["cannon", "permissioned"],
    }


def default_proposer_params():
    return {
        "image": DEFAULT_PROPOSER_IMAGES["op-proposer"],
        "extra_params": [],
        "game_type": 1,
        "proposal_interval": "10m",
    }


def default_signer_params():
    return {
        "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-signer",
        "tag": "v1.5.0",
        "extra_params": [],
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


def default_op_contract_deployer_global_deploy_overrides():
    return {
        "faultGameAbsolutePrestate": "",
    }


def default_op_contract_deployer_params():
    return {
        "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.0.12",
        "l1_artifacts_locator": "https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-fffcbb0ebf7f83311791534a41e65ef90df47797f9ca8f86941452f597f7128c.tar.gz",
        "l2_artifacts_locator": "https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-fffcbb0ebf7f83311791534a41e65ef90df47797f9ca8f86941452f597f7128c.tar.gz",
        "global_deploy_overrides": default_op_contract_deployer_global_deploy_overrides(),
    }


def default_ethereum_package_network_params():
    return {
        "participants": [
            {
                "el_type": "geth",
                "cl_type": "teku",
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


def default_da_server_params():
    return {
        "enabled": False,
        "image": DEFAULT_DA_SERVER_PARAMS["image"],
        "cmd": DEFAULT_DA_SERVER_PARAMS["cmd"],
    }


def default_tx_fuzzer_params():
    return {
        "image": "ethpandaops/tx-fuzz:master",
        "tx_fuzzer_extra_args": [],
    }
