"""
Tests for the op-faucet launcher.
"""

op_faucet_launcher = import_module("/src/faucet/op-faucet/op_faucet_launcher.star")
input_parser = import_module("/src/package_io/input_parser.star")
constants = import_module("/src/package_io/constants.star")


def test_launch_with_defaults(plan):
    """Test launching the op-faucet service with default parameters."""
    faucet_image = "op-faucet:latest"
    service_name = "op-faucet"

    # Create test faucet data
    faucets = [
        op_faucet_launcher.faucet_data(
            chain_id="1",
            el_rpc="http://l1-rpc",
            private_key=constants.dev_accounts[0]["private_key"],
            name="l1",
        ),
        op_faucet_launcher.faucet_data(
            chain_id="10",
            el_rpc="http://l2-rpc",
            private_key=constants.dev_accounts[1]["private_key"],
            name="l2",
        ),
    ]

    op_faucet_launcher.launch(
        plan=plan,
        service_name=service_name,
        image=faucet_image,
        faucets=faucets,
    )

    # Verify service configuration
    faucet_service_config = kurtosistest.get_service_config(service_name=service_name)
    expect.ne(faucet_service_config, None)
    expect.eq(faucet_service_config.image, faucet_image)
    expect.eq(faucet_service_config.env_vars, {})
    expect.eq(faucet_service_config.entrypoint, [])
    expect.eq(
        faucet_service_config.cmd,
        [
            "op-faucet",
            "--rpc.port=9000",
            "--config=/config/config.yaml",
        ],
    )
    expect.eq(faucet_service_config.ports["rpc"].number, 9000)
    expect.eq(faucet_service_config.ports["rpc"].transport_protocol, "TCP")
    expect.eq(faucet_service_config.ports["rpc"].application_protocol, "http")


def test_launch_with_custom_image(plan):
    """Test launching the op-faucet service with a custom image."""
    custom_image = "custom-op-faucet:latest"
    service_name = "op-faucet"

    # Create test faucet data
    faucets = [
        op_faucet_launcher.faucet_data(
            chain_id="1",
            el_rpc="http://l1-rpc",
            private_key=constants.dev_accounts[0]["private_key"],
        ),
    ]

    op_faucet_launcher.launch(
        plan=plan,
        service_name=service_name,
        image=custom_image,
        faucets=faucets,
    )

    # Verify service configuration
    faucet_service_config = kurtosistest.get_service_config(service_name=service_name)
    expect.eq(faucet_service_config.image, custom_image)
