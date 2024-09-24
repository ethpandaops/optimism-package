PARTICIPANT_CATEGORIES = {
    "participants": [
        "el_type",
        "el_image",
        "cl_type",
        "cl_image",
        "count",
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
    "op_contract_deployer_params": ["image"],
    "da_server_params": [
        "image",
        "build_image",
        "da_server_extra_args",
        "generic_commitment",
    ],
}

ADDITIONAL_SERVICES_PARAMS = [
    "blockscout",
    "da_server",
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


def sanity_check(plan, input_args):
    if type(input_args) == "list":
        return "Cant bother with your input, you shall pass"

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
        combined_root_params = PARTICIPANT_CATEGORIES.keys() + SUBCATEGORY_PARAMS.keys()
        combined_root_params.append("additional_services")

        if param not in combined_root_params:
            fail(
                "Invalid parameter {0}, allowed fields {1}".format(
                    param, combined_root_params
                )
            )

    # If everything passes, print a message
    plan.print("Sanity check for OP package passed")
