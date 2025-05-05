"""
Tests for the proxyd launcher.
"""

proxyd_launcher = import_module("/src/proxyd/proxyd_launcher.star")
input_parser = import_module("/src/package_io/input_parser.star")
constants = import_module("/src/package_io/constants.star")
observability = import_module("/src/observability/observability.star")


def test_launch_with_defaults(plan):
    """Test launching the proxyd service with default parameters."""
    proxyd_image = input_parser.DEFAULT_PROXYD_IMAGES["proxyd"]
    image, tag = proxyd_image.split(":")

    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": "1",
                        "network": "testnet",
                    },
                }
            ],
        },
    )

    proxyd_params = struct(
        image=image,
        tag=tag,
        replicas={
            "replica1": "http://replica1:8545",
            "replica2": "http://replica2:8545",
        },
        extra_params=[],
    )

    network_params = parsed_input_args.chains[0].network_params

    el_contexts = [
        struct(
            client_name="replica1",
            rpc_http_url="http://replica1:8545",
        ),
        struct(
            client_name="replica2",
            rpc_http_url="http://replica2:8545",
        ),
    ]

    observability_helper = observability.make_helper(parsed_input_args.observability)

    proxyd_launcher.launch(
        plan=plan,
        proxyd_params=proxyd_params,
        network_params=network_params,
        el_contexts=el_contexts,
        observability_helper=observability_helper,
    )

    # Verify service configuration
    proxyd_service_config = kurtosistest.get_service_config(service_name="proxyd-1")
    expect.ne(proxyd_service_config, None)
    expect.eq(proxyd_service_config.image, proxyd_image)
    expect.eq(proxyd_service_config.env_vars, {})
    expect.eq(proxyd_service_config.entrypoint, [])
    expect.eq(
        proxyd_service_config.cmd,
        [
            "proxyd",
            "/etc/proxyd/proxyd.toml",
        ],
    )
    expect.eq(proxyd_service_config.ports[constants.HTTP_PORT_ID].number, 8080)
    expect.eq(
        proxyd_service_config.ports[constants.HTTP_PORT_ID].transport_protocol, "TCP"
    )
    expect.eq(
        proxyd_service_config.ports[constants.HTTP_PORT_ID].application_protocol, "http"
    )
    expect.eq(proxyd_service_config.ports["metrics"].number, 7300)
    expect.eq(proxyd_service_config.ports["metrics"].transport_protocol, "TCP")
    expect.eq(proxyd_service_config.ports["metrics"].application_protocol, "http")


def test_launch_with_custom_image(plan):
    """Test launching the proxyd service with a custom image."""
    custom_image = "custom-proxyd"

    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": "1",
                        "network": "testnet",
                    },
                }
            ],
        },
    )

    proxyd_params = struct(
        image=custom_image,
        replicas={
            "replica1": "http://replica1:8545",
        },
        extra_params=[],
        tag="latest",
    )

    network_params = parsed_input_args.chains[0].network_params

    el_contexts = [
        struct(
            client_name="replica1",
            rpc_http_url="http://replica1:8545",
        )
    ]

    observability_helper = observability.make_helper(parsed_input_args.observability)

    proxyd_launcher.launch(
        plan=plan,
        proxyd_params=proxyd_params,
        network_params=network_params,
        el_contexts=el_contexts,
        observability_helper=observability_helper,
    )

    proxyd_service_config = kurtosistest.get_service_config(service_name="proxyd-1")
    expect.eq(proxyd_service_config.image, custom_image + ":" + proxyd_params.tag)
    expect.eq(proxyd_service_config.ports[constants.HTTP_PORT_ID].number, 8080)
    expect.eq(proxyd_service_config.ports["metrics"].number, 7300)


def test_launch_with_metrics_disabled(plan):
    """Test launching the proxyd service with metrics disabled."""
    proxyd_image = input_parser.DEFAULT_PROXYD_IMAGES["proxyd"]

    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": "1",
                        "network": "testnet",
                    },
                }
            ],
            "observability": {
                "enabled": False,
            },
        },
    )

    proxyd_params = struct(
        image=proxyd_image,
        replicas={
            "replica1": "http://replica1:8545",
        },
        extra_params=[],
        tag="latest",
    )

    network_params = parsed_input_args.chains[0].network_params

    el_contexts = [
        struct(
            client_name="replica1",
            rpc_http_url="http://replica1:8545",
        )
    ]

    observability_helper = observability.make_helper(parsed_input_args.observability)

    proxyd_launcher.launch(
        plan=plan,
        proxyd_params=proxyd_params,
        network_params=network_params,
        el_contexts=el_contexts,
        observability_helper=observability_helper,
    )

    proxyd_service_config = kurtosistest.get_service_config(service_name="proxyd-1")
    expect.ne(proxyd_service_config, None)
    expect.eq(proxyd_service_config.image, proxyd_image + ":" + proxyd_params.tag)
    expect.eq(proxyd_service_config.ports[constants.HTTP_PORT_ID].number, 8080)
    expect.eq("metrics" in proxyd_service_config.ports, False)


def test_launch_with_extra_params(plan):
    """Test launching the proxyd service with extra command line parameters."""
    proxyd_image = "us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd"

    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": "1",
                        "network": "testnet",
                    },
                }
            ],
        },
    )

    proxyd_params = struct(
        image=proxyd_image,
        replicas={
            "replica1": "http://replica1:8545",
        },
        extra_params=[
            "--log.level=debug",
            "--max-body-size=10MB",
        ],
        tag="latest",
    )

    network_params = parsed_input_args.chains[0].network_params

    el_contexts = [
        struct(
            client_name="replica1",
            rpc_http_url="http://replica1:8545",
        )
    ]

    observability_helper = observability.make_helper(parsed_input_args.observability)

    proxyd_launcher.launch(
        plan=plan,
        proxyd_params=proxyd_params,
        network_params=network_params,
        el_contexts=el_contexts,
        observability_helper=observability_helper,
    )

    proxyd_service_config = kurtosistest.get_service_config(service_name="proxyd-1")
    expect.ne(proxyd_service_config, None)
    expect.eq(proxyd_service_config.image, proxyd_image + ":" + proxyd_params.tag)
    expect.eq(
        proxyd_service_config.cmd,
        [
            "proxyd",
            "/etc/proxyd/proxyd.toml",
            "--log.level=debug",
            "--max-body-size=10MB",
        ],
    )


def test_launch_with_multiple_replicas(plan):
    """Test launching the proxyd service with multiple replicas."""
    proxyd_image = "us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd"

    parsed_input_args = input_parser.input_parser(
        plan,
        {
            "chains": [
                {
                    "network_params": {
                        "network_id": "1",
                        "network": "testnet",
                    },
                }
            ],
        },
    )

    proxyd_params = struct(
        image=proxyd_image,
        replicas={
            "replica1": "http://replica1:8545",
            "replica2": "http://replica2:8545",
            "replica3": "http://replica3:8545",
        },
        extra_params=[],
        tag="latest",
    )

    network_params = parsed_input_args.chains[0].network_params

    el_contexts = [
        struct(
            client_name="replica1",
            rpc_http_url="http://replica1:8545",
        ),
        struct(
            client_name="replica2",
            rpc_http_url="http://replica2:8545",
        ),
        struct(
            client_name="replica3",
            rpc_http_url="http://replica3:8545",
        ),
    ]

    observability_helper = observability.make_helper(parsed_input_args.observability)

    service_url = proxyd_launcher.launch(
        plan=plan,
        proxyd_params=proxyd_params,
        network_params=network_params,
        el_contexts=el_contexts,
        observability_helper=observability_helper,
    )

    proxyd_service_config = kurtosistest.get_service_config(service_name="proxyd-1")
    expect.ne(proxyd_service_config, None)
    expect.eq(proxyd_service_config.image, proxyd_image + ":" + proxyd_params.tag)

    # Verify the config file is mounted correctly
    expect.eq(
        proxyd_service_config.files["/etc/proxyd"].artifact_names[0], "proxyd-config-1"
    )

    # We can't verify the config file content here because it's rendered as a template
    # and we don't have access to the rendered content in the test.
