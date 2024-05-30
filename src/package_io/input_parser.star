ethereum_package_input_parser = import_module("github.com/kurtosis-tech/ethereum-package/src/package_io/input_parser.star")

DEFAULT_EL_IMAGES = {
    "op-geth": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
}

DEFAULT_CL_IMAGES = {
    "op-node": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
}

DEFAULT_BATCHER_IMAGES = {
    "op-batcher": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:develop",
}

DEFAULT_PROPOSER_IMAGES = {
    "op-proposer": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:develop",
}

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
)

def input_parser(plan, input_args):
    result = parse_network_params(plan, input_args)

    return struct(
        participants=[
            struct(
                el_type=participant["el_type"],
                el_image=participant["el_image"],
                cl_type=participant["cl_type"],
                cl_image=participant["cl_image"],
                count=participant["count"],
            )
            for participant in result["participants"]
        ],
        network_params=struct(
            network=result["network_params"]["network"],
        ),
    )

def parse_network_params(plan, input_args):
    result = default_input_args(input_args)

    for attr in input_args:
        value = input_args[attr]
        # if its insterted we use the value inserted
        if attr not in ATTR_TO_BE_SKIPPED_AT_ROOT and attr in input_args:
            result[attr] = value
        elif attr == "network_params":
            for sub_attr in input_args["network_params"]:
                sub_value = input_args["network_params"][sub_attr]
                result["network_params"][sub_attr] = sub_value
        elif attr == "participants":
            participants = []
            for participant in input_args["participants"]:
                new_participant = default_participant()
                for sub_attr, sub_value in participant.items():
                    # if the value is set in input we set it in participant
                    new_participant[sub_attr] = sub_value
                for _ in range(0, new_participant["count"]):
                    participant_copy = ethereum_package_input_parser.deep_copy_participant(new_participant)
                    participants.append(participant_copy)
            result["participants"] = participants

    for index, participant in enumerate(result["participants"]):
        el_type = participant["el_type"]
        cl_type = participant["cl_type"]
        el_image = participant["el_image"]
        cl_image = participant["cl_image"]

    return result

def default_input_args(input_args):
    network_params = default_network_params()
    participants = [default_participant()]
    return {
        "participants": participants,
        "network_params": network_params,
    }

def default_network_params():
    return {
        "network": "kurtosis",
    }

def default_participant():
    return {
        "el_type": "op-geth",
        "el_image": "",
        "cl_type": "op-node",
        "cl_image": "",
        "count": 1,
    }
