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
