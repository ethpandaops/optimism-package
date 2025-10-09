main = import_module("/main.star")


def test_multiple_chains(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": {
                    "opkurtosis": {
                        "network_params": {
                            "network_id": "1000",
                        },
                        "participants": {"node0": {}},
                    },
                    "nopekurtosis": {
                        "network_params": {
                            "network_id": "2000",
                        },
                        "participants": {"node0": {}},
                    },
                },
            },
        },
    )

    services = plan.get_services()
    cl_service_names = [
        service.name for service in services if service.name.startswith("op-cl-")
    ]
    expect.eq(
        cl_service_names,
        ["op-cl-1000-node0-op-node", "op-cl-2000-node0-op-node"],
    )

    el_service_names = [
        service.name for service in services if service.name.startswith("op-el-")
    ]
    expect.eq(
        el_service_names,
        ["op-el-1000-node0-op-geth", "op-el-2000-node0-op-geth"],
    )


def test_multiple_chains_with_flashblocks(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": {
                    "opkurtosis": {
                        "network_params": {
                            "network_id": "1000",
                        },
                        "participants": {"node0": {}},
                        "flashblocks_rpc_params": {
                            "type": "op-reth",
                        },
                        "flashblocks_websocket_proxy_params": {
                            "enabled": True,
                        },
                    },
                },
            },
        },
    )

    services = plan.get_services()

    # Check that flashblocks services are launched
    flashblocks_rpc_service_names = [
        service.name
        for service in services
        if service.name.startswith("op-el-1000-flashblocks-rpc")
    ]
    expect.eq(len(flashblocks_rpc_service_names), 1)

    flashblocks_websocket_proxy_service_names = [
        service.name
        for service in services
        if service.name.startswith("flashblocks-websocket-proxy")
    ]
    expect.eq(len(flashblocks_websocket_proxy_service_names), 1)
