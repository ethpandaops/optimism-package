constants = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/package_io/constants.star"
)
shared_utils = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star"
)

op_node = import_module("./op-node/op_node_launcher.star")


def launch(
    plan,
    jwt_file,
    network_params,
    el_cl_data,
    participants,
    num_participants,
    all_el_contexts,
    l1_config_env_vars,
    gs_sequencer_private_key,
):
    plan.print("Launching CL network")

    cl_launchers = {
        "op-node": {
            "launcher": op_node.new_op_node_launcher(
                el_cl_data, jwt_file, network_params
            ),
            "launch_method": op_node.launch,
        },
    }
    all_cl_contexts = []

    for index, participant in enumerate(participants):
        cl_type = participant.cl_type
        el_type = participant.el_type

        if cl_type not in cl_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    cl_type, ",".join(cl_launchers.keys())
                )
            )

        cl_launcher, launch_method = (
            cl_launchers[cl_type]["launcher"],
            cl_launchers[cl_type]["launch_method"],
        )

        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        cl_service_name = "op-cl-{0}-{1}-{2}".format(index_str, cl_type, el_type)

        el_context = all_el_contexts[index]

        cl_context = None

        full_name = "{0}-{1}-{2}".format(index_str, el_type, cl_type)

        cl_context = launch_method(
            plan,
            cl_launcher,
            cl_service_name,
            participant.cl_image,
            el_context,
            all_cl_contexts,
            l1_config_env_vars,
            gs_sequencer_private_key,
        )

        all_cl_contexts.append(cl_context)
    return all_cl_contexts
