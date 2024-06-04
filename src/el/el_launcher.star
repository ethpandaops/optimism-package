constants = import_module("github.com/kurtosis-tech/ethereum-package/src/package_io/constants.star")
shared_utils = import_module("github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star")

op_geth = import_module("./op-geth/op_geth_launcher.star")





def launch(
    plan,
    jwt_file,
    network_params,
    el_cl_data,
    participants,
    num_participants,
):
    el_launchers = {
        "op-geth": {
            "launcher": op_geth.new_op_geth_launcher(
                el_cl_data,
                jwt_file,
                network_params.network,
                network_params.network_id,
            ),
            "launch_method": op_geth.launch,
        },
    }

    all_el_contexts = []

    for index, participant in enumerate(participants):
        cl_type = participant.cl_type
        el_type = participant.el_type

        if el_type not in el_launchers:
            fail(
                "Unsupported launcher '{0}', need one of '{1}'".format(
                    el_type, ",".join(el_launchers.keys())
                )
            )

        el_launcher, launch_method = (
            el_launchers[el_type]["launcher"],
            el_launchers[el_type]["launch_method"],
        )

        # Zero-pad the index using the calculated zfill value
        index_str = shared_utils.zfill_custom(index + 1, len(str(len(participants))))

        el_service_name = "op-el-{0}-{1}-{2}".format(index_str, el_type, cl_type)

        el_context = launch_method(
            plan,
            el_launcher,
            el_service_name,
            participant.el_image,
            all_el_contexts,
        )
        # # Add participant el additional prometheus metrics
        # for metrics_info in el_context.el_metrics_info:
        #     if metrics_info != None:
        #         metrics_info["config"] = participant.prometheus_config

        all_el_contexts.append(el_context)

    plan.print("Successfully added {0} EL participants".format(num_participants))
    return all_el_contexts
