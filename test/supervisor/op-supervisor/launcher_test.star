_op_supervisor_launcher = import_module("/src/supervisor/op-supervisor/launcher.star")

_input_parser = import_module("/src/package_io/input_parser.star")
_observability = import_module("/src/observability/observability.star")
_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)


def test_interop_op_supervisor_ports(plan):
    parsed_input_args = _input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": 1000,
                    },
                    "participants": [
                        {
                            "el_type": "op-reth",
                            "el_image": "op-reth:latest",
                            "cl_type": "op-node",
                            "cl_image": "op-node:latest",
                        }
                    ],
                }
            ],
            "superchains": {"superchain0": {}},
            "supervisors": {
                "supervisor0": {
                    "superchain": "superchain0",
                }
            },
        },
    )

    # Just to make sure
    expect.ne(parsed_input_args.supervisors, None)

    supervisor_params = parsed_input_args.supervisors[0]
    expect.ne(supervisor_params, None)

    observability_helper = _observability.make_helper(parsed_input_args.observability)

    result = _op_supervisor_launcher.launch(
        plan=plan,
        l1_config_env_vars={"L1_RPC_URL": "http://l1.rpc"},
        l2s=[],
        jwt_file="/jwt_file",
        params=supervisor_params,
        observability_helper=observability_helper,
    )

    service = plan.get_service(supervisor_params.service_name)
    expect.ne(service, None)

    expect.eq(service.ports["rpc"].number, 8545)
    expect.eq(service.ports["rpc"].application_protocol, "http")

    service_config = kurtosistest.get_service_config(supervisor_params.service_name)
    expect.ne(service_config, None)

    expect.eq(service_config.env_vars["OP_SUPERVISOR_RPC_ADDR"], "0.0.0.0")
    expect.eq(service_config.env_vars["OP_SUPERVISOR_RPC_PORT"], "8545")

    expect.eq(
        supervisor_params.superchain.dependency_set.name,
        "superchain-depset-superchain0",
    )
    expect.eq(
        supervisor_params.superchain.dependency_set.path,
        "superchain-depset-superchain0.json",
    )
    expect.eq(
        service_config.env_vars["OP_SUPERVISOR_DEPENDENCY_SET"],
        "/etc/op-supervisor/superchain-depset-superchain0.json",
    )
    expect.eq(
        service_config.files["/etc/op-supervisor"].artifact_names,
        ["superchain-depset-superchain0"],
    )
