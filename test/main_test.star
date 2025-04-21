main = import_module("/main.star")


def test_multiple_chains(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": [
                    {
                        "network_params": {
                            "network_id": "1000",
                        }
                    },
                    {
                        "network_params": {
                            "network_id": "2000",
                        }
                    },
                ],
            },
        },
    )

    services = plan.get_services()
    cl_service_names = [
        service.name for service in services if service.name.startswith("op-cl-")
    ]
    expect.eq(
        cl_service_names,
        [
            "op-cl-1000-1-op-node-op-geth-op-kurtosis",
            "op-cl-2000-1-op-node-op-geth-op-kurtosis",
        ],
    )

    el_service_names = [
        service.name for service in services if service.name.startswith("op-el-")
    ]
    expect.eq(
        el_service_names,
        [
            "op-el-1000-1-op-geth-op-node-op-kurtosis",
            "op-el-2000-1-op-geth-op-node-op-kurtosis",
        ],
    )
