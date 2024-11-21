ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

sanity_check = import_module("./sanity_check.star")

DEFAULT_EL_IMAGES = {
    "op-geth": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
    "op-reth": "ghcr.io/paradigmxyz/op-reth:latest",
    "op-erigon": "testinprod/op-erigon:latest",
    "op-nethermind": "nethermind/nethermind:latest",
    "op-besu": "ghcr.io/optimism-java/op-besu:latest",
}

DEFAULT_CL_IMAGES = {
    "op-node": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
    "hildr": "ghcr.io/optimism-java/hildr:latest",
}

DEFAULT_BATCHER_IMAGES = {
    "op-batcher": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:develop",
}

DEFAULT_PROPOSER_IMAGES = {
    "op-proposer": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:develop",
}

DEFAULT_ADDITIONAL_SERVICES = []


def input_parser(plan, input_args):
    sanity_check.sanity_check(plan, input_args)
    results = parse_network_params(plan, input_args)
    results["global_log_level"] = "info"
    results["global_node_selectors"] = {}
    results["global_tolerations"] = []
    results["persistent"] = False
    return struct(
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
                batcher_params=struct(
                    image=result["batcher_params"]["image"],
                    extra_params=result["batcher_params"]["extra_params"],
                ),
                additional_services=result["additional_services"],
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
        ),
        global_log_level=results["global_log_level"],
        global_node_selectors=results["global_node_selectors"],
        global_tolerations=results["global_tolerations"],
        persistent=results["persistent"],
    )


def parse_network_params(plan, input_args):
    results = {}
    chains = []

    seen_names = {}
    seen_network_ids = {}
    for chain in input_args.get("chains", default_chains()):
        network_params = default_network_params()
        network_params.update(chain.get("network_params", {}))

        batcher_params = default_batcher_params()
        batcher_params.update(chain.get("batcher_params", {}))

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

            for _ in range(0, participant["count"]):
                participant_copy = ethereum_package_input_parser.deep_copy_participant(
                    participant
                )
                participants.append(participant_copy)

        result = {
            "participants": participants,
            "network_params": network_params,
            "batcher_params": batcher_params,
            "additional_services": chain.get(
                "additional_services", DEFAULT_ADDITIONAL_SERVICES
            ),
        }
        chains.append(result)

    results["chains"] = chains
    results["op_contract_deployer_params"] = default_op_contract_deployer_params()
    results["op_contract_deployer_params"].update(
        input_args.get("op_contract_deployer_params", {})
    )
    results["global_log_level"] = input_args.get("global_log_level", "info")

    return results


def default_optimism_args():
    return {
        "chains": default_chains(),
        "op_contract_deployer_params": default_op_contract_deployer_params(),
        "global_log_level": "info",
        "global_node_selectors": {},
        "global_tolerations": [],
        "persistent": False,
    }


def default_chains():
    return [
        {
            "participants": [default_participant()],
            "network_params": default_network_params(),
            "batcher_params": default_batcher_params(),
            "additional_services": DEFAULT_ADDITIONAL_SERVICES,
        }
    ]


def default_network_params():
    return {
        "network": "kurtosis",
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
        "image": "",
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
        "node_selectors": {},
        "tolerations": [],
        "count": 1,
    }


def default_op_contract_deployer_params():
    return {
        "image": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.0.6",
        "l1_artifacts_locator": "tag://op-contracts/v1.6.0",
        "l2_artifacts_locator": "tag://op-contracts/v1.7.0-beta.1+l2-contracts",
    }


def default_ethereum_package_network_params():
    return {
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
        }
    }
