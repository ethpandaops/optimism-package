ethereum_package_input_parser = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/input_parser.star"
)

DEFAULT_EL_IMAGES = {
    "op-geth": "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
    "op-reth": "parithoshj/op-reth:latest",
}

DEFAULT_CL_IMAGES = {
    "op-node": "parithoshj/op-node:v1",
}

DEFAULT_BATCHER_IMAGES = {
    "op-batcher": "parithoshj/op-batcher:v1",
}

DEFAULT_PROPOSER_IMAGES = {
    "op-proposer": "parithoshj/op-proposer:v1",
}

ATTR_TO_BE_SKIPPED_AT_ROOT = (
    "network_params",
    "participants",
)


DEFAULT_ADDITIONAL_SERVICES = []


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
            network_id=result["network_params"]["network_id"],
            seconds_per_slot=result["network_params"]["seconds_per_slot"],
        ),
        additional_services=result.get(
            "additional_services", DEFAULT_ADDITIONAL_SERVICES
        ),
    )


def parse_network_params(plan, input_args):
    result = default_input_args(input_args)
    plan.print("result inside parse network params: {0}".format(result))

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
                    participant_copy = (
                        ethereum_package_input_parser.deep_copy_participant(
                            new_participant
                        )
                    )
                    participants.append(participant_copy)
            result["participants"] = participants

    for index, participant in enumerate(result["participants"]):
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
            if cl_image == "":
                default_image = DEFAULT_CL_IMAGES.get(cl_type, "")
            if default_image == "":
                fail(
                    "{0} received an empty image name and we don't have a default for it".format(
                        cl_type
                    )
                )
            participant["cl_image"] = default_image

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
        "network_id": "2151908",
        "name": "op-kurtosis",
        "seconds_per_slot": 2,
    }


def default_participant():
    return {
        "el_type": "op-geth",
        "el_image": "",
        "cl_type": "op-node",
        "cl_image": "",
        "count": 1,
    }
