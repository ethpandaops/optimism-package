op_supervisor_launcher = import_module("./src/supervisor/op-supervisor/launcher.star")
kona_supervisor_launcher = import_module("./src/supervisor/kona-supervisor/launcher.star")

def launch(
    plan,
    params,
    l1_config_env_vars,
    l2s,
    jwt_file,
    deployment_output,
    observability_helper,
):
    supervisor_type = params.supervisor_params["type"]

    if supervisor_type == "op-supervisor":
        return op_supervisor_launcher.launch(
            plan=plan,
            params=params,
            l1_config_env_vars=l1_config_env_vars,
            l2s=l2s,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
        )
    elif supervisor_type == "kona-supervisor":
        return kona_supervisor_launcher.launch(
            plan=plan,
            params=params,
            l1_config_env_vars=l1_config_env_vars,
            l2s=l2s,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
        )
    else:
        fail(
            "Unsupported supervisor implementation {}".format(
                supervisor_type
            )
        )