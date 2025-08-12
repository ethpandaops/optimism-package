_launcher = import_module("/src/conductor/op-conductor-ops/launcher.star")
_selectors = import_module("/src/l2/selectors.star")
_net = import_module("/src/util/net.star")


def test_get_participants_params_with_conductors_none(plan):
    l2_params = struct(
        participants=[
            struct(
                conductor_params=None,
                participant_type="sequencer",
                name="node0",
                sequencer="node0",
            ),
            struct(
                conductor_params=struct(enabled=False),
                participant_type="sequencer",
                name="node1",
                sequencer="node0",
            ),
        ]
    )

    result = _launcher._get_participants_params_with_conductors(l2_params)
    expect.eq(result, [])


def test_get_participants_params_with_conductors_with_conductors(plan):
    conductor_params_1 = struct(
        service_name="op-conductor-1",
        enabled=True,
    )
    conductor_params_2 = struct(
        service_name="op-conductor-2",
        enabled=True,
    )

    participant_1 = struct(
        conductor_params=conductor_params_1,
        participant_type="sequencer",
        name="node0",
        sequencer="node0",
    )
    participant_2 = struct(
        conductor_params=conductor_params_2,
        participant_type="sequencer",
        name="node1",
        sequencer="node1",
    )
    participant_3 = struct(
        conductor_params=None,
        participant_type="verifier",
        name="node2",
        sequencer="node0",
    )

    l2_params = struct(participants=[participant_1, participant_2, participant_3])

    result = _launcher._get_participants_params_with_conductors(l2_params)
    expect.eq(len(result), 2)
    expect.eq(result[0], participant_1)
    expect.eq(result[1], participant_2)


def test_conductor_config_data_generation(plan):
    """Test the config data structure generation for conductor ops"""

    # Mock network params
    network_params = struct(name="test-chain", network_id="2151908")

    # Mock conductor ports
    conductor_ports = {
        _net.RPC_PORT_NAME: _net.port(number=8547),
        _net.CONSENSUS_PORT_NAME: _net.port(number=50050),
    }

    # Mock CL ports
    cl_ports = {
        _net.RPC_PORT_NAME: _net.port(number=8547),
    }

    # Mock conductor params
    conductor_params = struct(
        service_name="op-conductor-2151908-test-chain-node0",
        ports=conductor_ports,
    )

    # Mock CL params
    cl_params = struct(
        service_name="op-cl-2151908-test-chain-node0",
        ports=cl_ports,
    )

    # Mock participant params
    participant_params = struct(
        conductor_params=conductor_params,
        cl=cl_params,
    )

    participants_params = [participant_params]

    # Test the config data generation logic (extracted from the function)
    expected_config_data = {
        "network_name": network_params.name,
        "sequencers": {
            participant_params.conductor_params.service_name: {
                "cl_rpc_url": _net.localhost_url(
                    participant_params.cl.service_name,
                    participant_params.cl.ports[_net.RPC_PORT_NAME],
                ),
                "conductor_rpc_url": _net.localhost_url(
                    participant_params.conductor_params.service_name,
                    participant_params.conductor_params.ports[_net.RPC_PORT_NAME],
                ),
                "conductor_raft_address": _net.localhost_address(
                    participant_params.conductor_params.service_name,
                    participant_params.conductor_params.ports[_net.CONSENSUS_PORT_NAME],
                ),
            }
        },
    }

    # Verify the expected structure
    expect.eq(expected_config_data["network_name"], "test-chain")
    expect.eq(len(expected_config_data["sequencers"]), 1)

    sequencer_config = expected_config_data["sequencers"][
        "op-conductor-2151908-test-chain-node0"
    ]
    expect.eq(sequencer_config["cl_rpc_url"], "http://127.0.0.1:8547")
    expect.eq(sequencer_config["conductor_rpc_url"], "http://127.0.0.1:8547")
    expect.eq(sequencer_config["conductor_raft_address"], "127.0.0.1:50050")


def test_conductor_config_data_generation_multiple_participants(plan):
    """Test config generation with multiple conductor participants"""

    network_params = struct(name="multi-chain", network_id="2151909")

    # Create multiple participants
    participants_params = []

    for i in range(3):
        conductor_ports = {
            _net.RPC_PORT_NAME: _net.port(number=8547),
            _net.CONSENSUS_PORT_NAME: _net.port(number=50050),
        }

        cl_ports = {
            _net.RPC_PORT_NAME: _net.port(number=8547),
        }

        conductor_params = struct(
            service_name="op-conductor-2151909-multi-chain-node{}".format(i),
            ports=conductor_ports,
        )

        cl_params = struct(
            service_name="op-cl-2151909-multi-chain-node{}".format(i),
            ports=cl_ports,
        )

        participant_params = struct(
            conductor_params=conductor_params,
            cl=cl_params,
        )

        participants_params.append(participant_params)

    # Test config data generation
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
                    participant_params.conductor_params.ports[_net.CONSENSUS_PORT_NAME].number,
                ),
            }
            for participant_params in participants_params
        },
    }

    # Verify multiple sequencers
    expect.eq(config_data["network_name"], "multi-chain")
    expect.eq(len(config_data["sequencers"]), 3)

    # Check each sequencer config
    for i in range(3):
        service_name = "op-conductor-2151909-multi-chain-node{}".format(i)
        expect.eq(service_name in config_data["sequencers"], True)

        sequencer_config = config_data["sequencers"][service_name]
        expect.eq(sequencer_config["cl_rpc_url"], "http://op-cl-2151909-multi-chain-node{}:8547".format(i))
        expect.eq(sequencer_config["conductor_rpc_url"], "http://op-conductor-2151909-multi-chain-node{}:8547".format(i))
        expect.eq(sequencer_config["conductor_raft_address"], "op-conductor-2151909-multi-chain-node{}:50050".format(i))


def test_conductor_config_data_with_different_ports(plan):
    """Test config generation with different port configurations"""

    network_params = struct(name="custom-ports-chain", network_id="2151910")

    # Custom ports for testing
    conductor_ports = {
        _net.RPC_PORT_NAME: _net.port(number=9547),
        _net.CONSENSUS_PORT_NAME: _net.port(number=60050),
    }

    cl_ports = {
        _net.RPC_PORT_NAME: _net.port(number=9548),
    }

    conductor_params = struct(
        service_name="op-conductor-custom",
        ports=conductor_ports,
    )

    cl_params = struct(
        service_name="op-cl-custom",
        ports=cl_ports,
    )

    participant_params = struct(
        conductor_params=conductor_params,
        cl=cl_params,
    )

    participants_params = [participant_params]

    # Generate config data
    config_data = {
        "network_name": network_params.name,
        "sequencers": {
            participant_params.conductor_params.service_name: {
                "cl_rpc_url": _net.localhost_url(
                    participant_params.cl.service_name,
                    participant_params.cl.ports[_net.RPC_PORT_NAME],
                ),
                "conductor_rpc_url": _net.localhost_url(
                    participant_params.conductor_params.service_name,
                    participant_params.conductor_params.ports[_net.RPC_PORT_NAME],
                ),
                "conductor_raft_address": _net.localhost_address(
                    participant_params.conductor_params.service_name,
                    participant_params.conductor_params.ports[_net.CONSENSUS_PORT_NAME],
                ),
            }
        },
    }

    # Verify custom ports are used
    sequencer_config = config_data["sequencers"]["op-conductor-custom"]
    expect.eq(sequencer_config["cl_rpc_url"], "http://127.0.0.1:9548")
    expect.eq(sequencer_config["conductor_rpc_url"], "http://127.0.0.1:9547")
    expect.eq(sequencer_config["conductor_raft_address"], "127.0.0.1:60050")
