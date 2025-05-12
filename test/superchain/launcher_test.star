_launcher = import_module("/src/superchain/launcher.star")
_input_parser = import_module("/src/superchain/input_parser.star")

_chains = [
    {"network_params": {"network_id": 1000}},
    {"network_params": {"network_id": 2000}},
]


def test_superchain_launcher_multiple_participants(plan):
    superchains_params = _input_parser.parse(
        {
            "superchain0": {},
            "superchain1": None,
            "superchain2": {
                "participants": [2000],
            },
            "superchain3": {
                "participants": [1000, 2000],
            },
        },
        _chains,
    )

    expect.eq(
        _launcher.launch(
            plan=plan,
            params=superchains_params[0],
        ),
        struct(
            dependency_set=struct(
                artifact="superchain-depset-superchain0",
                path="superchain-depset-superchain0.json",
                superchain="superchain0",
            )
        ),
    )

    expect.eq(
        _launcher.launch(
            plan=plan,
            params=superchains_params[1],
        ),
        struct(
            dependency_set=struct(
                artifact="superchain-depset-superchain1",
                path="superchain-depset-superchain1.json",
                superchain="superchain1",
            )
        ),
    )

    expect.eq(
        _launcher.launch(
            plan=plan,
            params=superchains_params[2],
        ),
        struct(
            dependency_set=struct(
                artifact="superchain-depset-superchain2",
                path="superchain-depset-superchain2.json",
                superchain="superchain2",
            )
        ),
    )

    expect.eq(
        _launcher.launch(
            plan=plan,
            params=superchains_params[3],
        ),
        struct(
            dependency_set=struct(
                artifact="superchain-depset-superchain3",
                path="superchain-depset-superchain3.json",
                superchain="superchain3",
            )
        ),
    )
