PARTICIPANT_CATEGORIES = {
    "participants": [
        "el_type",
        "el_image",
        "cl_type",
        "cl_image",
        "count",
        "sequencer",
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
        "interop_time_offset",
    ],
}

OP_CONTRACT_DEPLOYER_PARAMS = [
    "image",
    "artifacts_url",
]

ADDITIONAL_SERVICES_PARAMS = [
    "blockscout",
]

ROOT_PARAMS = [
    "chains",
    "op_contract_deployer_params",
]


def deep_validate_params(plan, input_args, category, allowed_params):
    if category in input_args:
        for item in input_args[category]:
            for param in item.keys():
                if param not in allowed_params:
                    fail(
                        "Invalid parameter {0} for {1}. Allowed fields: {2}".format(
                            param, category, allowed_params
                        )
                    )


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
        fail("Invalid input_args type, expected dict")

    for key in optimism_config.keys():
        if key not in ROOT_PARAMS:
            fail("Invalid parameter {0}, allowed fields: {1}".format(key, ROOT_PARAMS))

    chains = optimism_config.get("chains", [])

    if type(chains) != "list":
        fail("Invalid input_args type, expected list")

    for input_args in chains:
        # Checks participants
        deep_validate_params(
            plan, input_args, "participants", PARTICIPANT_CATEGORIES["participants"]
        )

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

    plan.print("Sanity check for OP package passed")
