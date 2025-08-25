_selectors = import_module("/src/l2/selectors.star")
_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_CONFIG_DIRPATH_ON_SERVICE = "/etc/op-conductor-ops"
_CONFIG_TEMPLATE_FILENAME = "config.toml.tmpl"
_CONFIG_FILENAME = "config.toml"


def launch(
    plan,
    l2_params,
    registry,
):
    participants_params = _get_participants_params_with_conductors(l2_params)
    if not participants_params:
        plan.print(
            "No conductors found for network {}, skipping op-conductor-ops launch".format(
                l2_params.network_params.name
            )
        )

        return None

    config_artifact = _create_op_conductor_ops_config_artifact(
        plan=plan,
        network_params=l2_params.network_params,
        participants_params=participants_params,
    )

    _run_op_conductor_ops_command(
        plan=plan,
        cmd="bootstrap-cluster {}".format(l2_params.network_params.name),
        config_artifact=config_artifact,
        description="Bootstrap conductors for network {} using op-conductor-ops, this operation may take a while to complete. Please check the task logs for progress.".format(
            l2_params.network_params.name
        ),
        registry=registry,
        env_vars={
            "BOOTSTRAP_SEQUENCER_START_TIMEOUT": "900",
            "BOOTSTRAP_SEQUENCER_HEALTHY_TIMEOUT": "900",
        },
    )

    _run_op_conductor_ops_command(
        plan=plan,
        cmd="status {}".format(l2_params.network_params.name),
        config_artifact=config_artifact,
        description="Get status of conductors for network {} using op-conductor-ops".format(
            l2_params.network_params.name
        ),
        registry=registry,
    )


def _run_op_conductor_ops_command(
    plan,
    cmd,
    config_artifact,
    description,
    registry,
    env_vars={},
):
    plan.run_sh(
        description=description,
        image=registry.get(_registry.OP_CONDUCTOR_OPS),
        files={
            _CONFIG_DIRPATH_ON_SERVICE: config_artifact,
        },
        run="./op-conductor-ops {}".format(
            cmd,
        ),
        env_vars=env_vars
        | {
            "CONDUCTOR_CONFIG": "{}/{}".format(
                _CONFIG_DIRPATH_ON_SERVICE, _CONFIG_FILENAME
            ),
        },
        wait=None,
    )


def _get_participants_params_with_conductors(l2_params):
    return [
        participant_params
        for participant_params in l2_params.participants
        if participant_params.conductor_params
        and _selectors.is_sequencer(participant_params)
    ]


def _create_op_conductor_ops_config_artifact(plan, network_params, participants_params):
    config_template = read_file(_CONFIG_TEMPLATE_FILENAME)
    config_data = {
        "network_name": network_params.name,
        "sequencers": {
            participant_params.conductor_params.service_name: {
                "cl_rpc_url": _net.service_url(
                    participant_params.cl.service_name,
                    participant_params.cl.ports[_net.RPC_PORT_NAME],
                ),
                "conductor_rpc_url": _net.service_url(
                    participant_params.conductor_params.service_name,
                    participant_params.conductor_params.ports[_net.RPC_PORT_NAME],
                ),
                "conductor_raft_address": "{0}:{1}".format(
                    participant_params.conductor_params.service_name,
                    participant_params.conductor_params.ports[
                        _net.CONSENSUS_PORT_NAME
                    ].number,
                ),
            }
            for participant_params in participants_params
        },
    }

    return plan.render_templates(
        {
            _CONFIG_FILENAME: struct(
                template=config_template,
                data=config_data,
            ),
        },
        name="op-conductor-ops-config-{0}".format(network_params.network_id),
    )
