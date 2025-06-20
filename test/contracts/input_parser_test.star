_input_parser = import_module("/src/contracts/input_parser.star")

_registry = import_module("/src/package_io/registry.star")

_default_registry = _registry.Registry()


def test_contracts_input_parser_default_args(plan):
    expect.eq(
        _input_parser.parse(
            args=None,
            registry=_default_registry,
        ),
        struct(
            image="us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.0-rc.2",
            l1_artifacts_locator="https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-02024c5a26c16fc1a5c716fff1c46b5bf7f23890d431bb554ddbad60971211d4.tar.gz",
            l2_artifacts_locator="https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-02024c5a26c16fc1a5c716fff1c46b5bf7f23890d431bb554ddbad60971211d4.tar.gz",
            overrides={},
        ),
    )


def test_contracts_input_parser_custom_args(plan):
    expect.eq(
        _input_parser.parse(
            args={
                "image": "op-deployer:latest",
                "l1_artifacts_locator": "artifact://l1-artifacts",
                "l2_artifacts_locator": "artifact://l2-artifacts",
            },
            registry=_default_registry,
        ),
        struct(
            image="op-deployer:latest",
            l1_artifacts_locator="artifact://l1-artifacts",
            l2_artifacts_locator="artifact://l2-artifacts",
            overrides={},
        ),
    )