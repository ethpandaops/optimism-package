ROOT_PARAMS = [
    "observability",
    "challengers",
    "superchains",
    "supervisors",
    "altda_deploy_config",
    "chains",
    "op_contract_deployer_params",
    "global_log_level",
    "global_node_selectors",
    "global_tolerations",
    "persistent",
    "faucet",
    "interop_mon",
]

OBSERVABILITY_PARAMS = [
    "enabled",
    "enable_k8s_features",
    "prometheus_params",
    "loki_params",
    "promtail_params",
    "grafana_params",
]

FAUCET_PARAMS = [
    "enabled",
    "image",
]

PROMETHEUS_PARAMS = [
    "image",
    "storage_tsdb_retention_time",
    "storage_tsdb_retention_size",
    "min_cpu",
    "max_cpu",
    "min_mem",
    "max_mem",
]

LOKI_PARAMS = [
    "image",
    "min_cpu",
    "max_cpu",
    "min_mem",
    "max_mem",
]

PROMTAIL_PARAMS = [
    "image",
    "min_cpu",
    "max_cpu",
    "min_mem",
    "max_mem",
]

GRAFANA_PARAMS = [
    "image",
    "dashboard_sources",
    "min_cpu",
    "max_cpu",
    "min_mem",
    "max_mem",
]

ALTDA_DEPLOY_CONFIG_PARAMS = [
    "use_altda",
    "da_commitment_type",
    "da_challenge_window",
    "da_resolve_window",
    "da_bond_size",
    "da_resolver_refund_percentage",
]

PARTICIPANT_CATEGORIES = {
    "participants": [
        "el",
        "el_builder",
        "cl",
        "cl_builder",
        "conductor_params",
        "mev_params",
    ],
}

SUBCATEGORY_PARAMS = {
    "network_params": [
        "network",
        "network_id",
        "seconds_per_slot",
        "name",
        "fjord_time_offset",
        "granite_time_offset",
        "holocene_time_offset",
        "isthmus_time_offset",
        "interop_time_offset",
        "fund_dev_accounts",
    ],
    "proxyd_params": ["image", "extra_params"],
    "batcher_params": ["image", "extra_params"],
    "proposer_params": ["image", "extra_params", "game_type", "proposal_interval"],
    "mev_params": ["image", "type", "builder_host", "builder_port"],
    "da_params": [
        "enabled",
        "image",
        "extra_params",
        "type",
    ],
    "tx_fuzzer_params": [
        "enabled",
        "image",
        "extra_params",
        "min_cpu",
        "max_cpu",
        "min_memory",
        "max_memory",
    ],
    "blockscout_params": [
        "enabled",
        "image",
        "verifier_image",
        "extra_params",
        "min_cpu",
        "max_cpu",
        "min_memory",
        "max_memory",
    ],
}

OP_CONTRACT_DEPLOYER_PARAMS = [
    "image",
    "l1_artifacts_locator",
    "l2_artifacts_locator",
    "overrides",
]

OP_CONTRACT_DEPLOYER_OVERRIDES = [
    "faultGameAbsolutePrestate",
    "vmType",
]

ADDITIONAL_SERVICES_PARAMS = ["rollup-boost"]

EXTERNAL_L1_NETWORK_PARAMS = [
    "network_id",
    "rpc_kind",
    "el_rpc_url",
    "el_ws_url",
    "cl_rpc_url",
    "priv_key",
]


def validate_params(plan, input_args, category, allowed_params):
    if category in input_args:
        for param in input_args[category].keys():
            if param not in allowed_params:
                fail(
                    "Invalid parameter {0} for {1}. Allowed fields: {2}".format(
                        param, category, allowed_params
                    )
                )


def sanity_check(plan, optimism_config):
    if type(optimism_config) != "dict":
        fail(
            "Invalid input_args type, expected dict, got {}".format(
                type(optimism_config)
            )
        )

    for key in optimism_config.keys():
        if key not in ROOT_PARAMS:
            fail("Invalid parameter {0}, allowed fields: {1}".format(key, ROOT_PARAMS))

    if "observability" in optimism_config:
        validate_params(
            plan,
            optimism_config,
            "observability",
            OBSERVABILITY_PARAMS,
        )

        if "prometheus_params" in optimism_config["observability"]:
            validate_params(
                plan,
                optimism_config["observability"],
                "prometheus_params",
                PROMETHEUS_PARAMS,
            )

        if "loki_params" in optimism_config["observability"]:
            validate_params(
                plan,
                optimism_config["observability"],
                "loki_params",
                LOKI_PARAMS,
            )

        if "promtail_params" in optimism_config["observability"]:
            validate_params(
                plan,
                optimism_config["observability"],
                "promtail_params",
                PROMTAIL_PARAMS,
            )

        if "grafana_params" in optimism_config["observability"]:
            validate_params(
                plan,
                optimism_config["observability"],
                "grafana_params",
                GRAFANA_PARAMS,
            )

    if "faucet" in optimism_config:
        validate_params(
            plan,
            optimism_config["faucet"],
            "faucet",
            FAUCET_PARAMS,
        )

    if "altda_deploy_config" in optimism_config:
        validate_params(
            plan,
            optimism_config["altda_deploy_config"],
            "altda_deploy_config",
            ALTDA_DEPLOY_CONFIG_PARAMS,
        )

    chains = optimism_config.get("chains", {})

    if type(chains) != "dict":
        fail("Invalid input_args type, expected dict, got {}".format(type(chains)))

    for input_args in chains.values():
        # Checks additional_services
        if "additional_services" in input_args:
            for additional_services in input_args["additional_services"]:
                if additional_services not in ADDITIONAL_SERVICES_PARAMS:
                    fail(
                        "Invalid additional_services {0}, allowed fields: {1}".format(
                            additional_services, ADDITIONAL_SERVICES_PARAMS
                        )
                    )

        # Checks subcategories
        for subcategories in SUBCATEGORY_PARAMS.keys():
            validate_params(
                plan, input_args, subcategories, SUBCATEGORY_PARAMS[subcategories]
            )
        # Checks everything else
        for param in input_args.keys():
            combined_root_params = (
                PARTICIPANT_CATEGORIES.keys() + SUBCATEGORY_PARAMS.keys()
            )
            combined_root_params.append("additional_services")
            combined_root_params.append("op_contract_deployer_params")

            if param not in combined_root_params:
                fail(
                    "Invalid parameter {0}, allowed fields {1}".format(
                        param, combined_root_params
                    )
                )

        # If everything passes, print a message

    if "op_contract_deployer_params" in optimism_config:
        validate_params(
            plan,
            optimism_config,
            "op_contract_deployer_params",
            OP_CONTRACT_DEPLOYER_PARAMS,
        )
        validate_params(
            plan,
            optimism_config["op_contract_deployer_params"],
            "overrides",
            OP_CONTRACT_DEPLOYER_OVERRIDES,
        )

    plan.print("Sanity check for OP package passed")


def external_l1_network_params_input_parser(plan, external_l1_network_params):
    for key in external_l1_network_params.keys():
        if key not in EXTERNAL_L1_NETWORK_PARAMS:
            fail(
                "Invalid parameter {0}, allowed fields: {1}".format(
                    key, EXTERNAL_L1_NETWORK_PARAMS
                )
            )
