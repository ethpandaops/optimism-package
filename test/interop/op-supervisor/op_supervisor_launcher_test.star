main = import_module("/main.star")

interop_constants = import_module("/src/interop/constants.star")


def get_l2_cl_services(plan):
    services = plan.get_services()

    return [s for s in services if s.name.startswith("op-cl-")]


def get_supervisor_services_by_service_name(plan):
    services = plan.get_services()

    return {
        s.name: s
        for s in services
        if s.name.startswith(interop_constants.SUPERVISOR_SERVICE_NAME)
    }


def expect_no_supervisors(plan):
    supervisor_services = get_supervisor_services_by_service_name(plan)

    expect.eq(supervisor_services, {})


def test_op_supervisor_disabled(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": [{}],
                "interop": {
                    "enabled": False,
                },
            },
        },
    )

    expect_no_supervisors(plan)


def test_op_supervisor_interop_set_disabled(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": [{}],
                "interop": {
                    "enabled": True,
                    "sets": [
                        {
                            "enabled": False,
                        }
                    ],
                },
            },
        },
    )

    expect_no_supervisors(plan)


def test_op_supervisor_interop_set_no_participants(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": [{}],
                "interop": {
                    "enabled": True,
                    "sets": [
                        {
                            "enabled": True,
                            "participants": [],
                        }
                    ],
                },
            },
        },
    )

    expect_no_supervisors(plan)


def test_op_supervisor_single_interop_set(plan):
    main.run(
        plan,
        {
            "optimism_package": {
                "chains": [
                    {
                        "network_params": {
                            "network_id": "1",
                        }
                    }
                ],
                "interop": {
                    "enabled": True,
                    "sets": [
                        {
                            "enabled": True,
                            "name": "great-interop-set-what-a-name",
                            "participants": "*",
                        }
                    ],
                },
            },
        },
    )

    cl_services = get_l2_cl_services(plan)
    cl_services_urls = [
        "ws://{0}:{1}".format(
            cl_service.ip_address,
            interop_constants.INTEROP_WS_PORT_NUM,
        )
        for cl_service in cl_services
    ]

    supervisor_services = get_supervisor_services_by_service_name(plan)
    supervisor_service = supervisor_services[
        "op-supervisor-great-interop-set-what-a-name"
    ]
    expect.ne(supervisor_service, None)

    supervisor_service_config = kurtosistest.get_service_config(supervisor_service.name)
    expect.ne(supervisor_service_config, None)

    expect.eq(
        supervisor_service_config.image,
        "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:develop",
    )
    expect.eq(
        supervisor_service_config.env_vars["OP_SUPERVISOR_L2_CONSENSUS_NODES"],
        ",".join(cl_services_urls),
    )


def test_op_supervisor_multiple_interop_sets(plan):
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
                    {
                        "network_params": {
                            "network_id": "3000",
                        }
                    },
                    {
                        "participants": [{}, {}],
                        "network_params": {
                            "network_id": "4000",
                        },
                    },
                ],
                "interop": {
                    "enabled": True,
                    "sets": [
                        {
                            "enabled": True,
                            "name": "great-interop-set-what-a-name",
                            "participants": ["1000", "3000"],
                        },
                        {
                            "enabled": True,
                            "name": "even-better-interop",
                            "participants": ["2000"],
                            "supervisor_params": {
                                "image": "op-supervisor:latest",
                                "extra_params": ["--foo", "--bar"],
                            },
                        },
                        {
                            "enabled": True,
                            "name": "but-wait-theres-more",
                            "participants": ["4000"],
                        },
                    ],
                },
            },
        },
    )

    supervisor_services = get_supervisor_services_by_service_name(plan)

    supervisor_service1 = supervisor_services[
        "op-supervisor-great-interop-set-what-a-name"
    ]
    expect.ne(supervisor_service1, None)

    supervisor_service2 = supervisor_services["op-supervisor-even-better-interop"]
    expect.ne(supervisor_service2, None)

    supervisor_service3 = supervisor_services["op-supervisor-but-wait-theres-more"]
    expect.ne(supervisor_service3, None)

    cl_services = get_l2_cl_services(plan)
    cl_services_urls_by_service_name = {
        s.name: "ws://{0}:{1}".format(
            s.ip_address,
            interop_constants.INTEROP_WS_PORT_NUM,
        )
        for s in cl_services
    }

    supervisor_service1_config = kurtosistest.get_service_config(
        supervisor_service1.name
    )
    expect.eq(
        supervisor_service1_config.env_vars["OP_SUPERVISOR_L2_CONSENSUS_NODES"],
        ",".join(
            [
                cl_services_urls_by_service_name[
                    "op-cl-1000-1-op-node-op-geth-op-kurtosis"
                ],
                cl_services_urls_by_service_name[
                    "op-cl-3000-1-op-node-op-geth-op-kurtosis"
                ],
            ]
        ),
    )

    supervisor_service2_config = kurtosistest.get_service_config(
        supervisor_service2.name
    )
    expect.eq(
        supervisor_service2_config.env_vars["OP_SUPERVISOR_L2_CONSENSUS_NODES"],
        cl_services_urls_by_service_name["op-cl-2000-1-op-node-op-geth-op-kurtosis"],
    )

    supervisor_service3_config = kurtosistest.get_service_config(
        supervisor_service3.name
    )
    expect.eq(
        supervisor_service3_config.env_vars["OP_SUPERVISOR_L2_CONSENSUS_NODES"],
        ",".join(
            [
                cl_services_urls_by_service_name[
                    "op-cl-4000-1-op-node-op-geth-op-kurtosis"
                ],
                cl_services_urls_by_service_name[
                    "op-cl-4000-2-op-node-op-geth-op-kurtosis"
                ],
            ]
        ),
    )
