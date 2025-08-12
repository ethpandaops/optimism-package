_op_test_sequencer_launcher = import_module(
    "/src/test-sequencer/op-test-sequencer/launcher.star"
)

_input_parser = import_module("/src/package_io/input_parser.star")
_observability = import_module("/src/observability/observability.star")


def test_interop_op_test_sequencer_ports(plan):
    parsed_input_args = _input_parser.input_parser(
        plan,
        {
            "chains": {
                "opkurtosis": {
                    "network_params": {
                        "network_id": 1000,
                    },
                    "participants": {
                        "node0": {
                            "el": {
                                "type": "op-reth",
                                "image": "op-reth:latest",
                            },
                            "cl": {
                                "type": "op-node",
                                "image": "op-node:latest",
                            },
                        }
                    },
                }
            },
            "test-sequencers": {"sequencer": {}},
        },
    )

    # Just to make sure
    expect.ne(parsed_input_args.test_sequencers, None)

    test_sequencer_params = parsed_input_args.test_sequencers[0]
    expect.ne(test_sequencer_params, None)

    observability_helper = _observability.make_helper(parsed_input_args.observability)

    _op_test_sequencer_launcher.launch(
        plan=plan,
        params=test_sequencer_params,
        l1_config_env_vars={"L1_RPC_URL": "http://l1.rpc"},
        l2s_params=[],
        jwt_file="/jwt_file",
        deployment_output="/deployment_output",
        observability_helper=observability_helper,
    )

    service = plan.get_service(test_sequencer_params.service_name)
    expect.ne(service, None)

    expect.eq(service.ports["rpc"].number, 8545)
    expect.eq(service.ports["rpc"].application_protocol, "http")

    service_config = kurtosistest.get_service_config(test_sequencer_params.service_name)
    expect.ne(service_config, None)

    expect.eq(service_config.env_vars["OP_TEST_SEQUENCER_RPC_ADDR"], "0.0.0.0")
    expect.eq(service_config.env_vars["OP_TEST_SEQUENCER_RPC_PORT"], "8545")
    expect.eq(
        service_config.env_vars["OP_TEST_SEQUENCER_BUILDERS_CONFIG"],
        "/config/builder_config.json",
    )
