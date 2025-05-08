_launcher = import_module("/src/superchain/launcher.star")
_input_parser = import_module("/src/superchain/input_parser.star")

_chains = [
    {"network_params": {"network_id": 1000}},
    {"network_params": {"network_id": 2000}},
]


def test_superchain_launcher_empty(plan):
    expect.eq(
        _launcher.launch(
            plan=plan,
            superchains_params=None,
        ),
        {},
    )
    expect.eq(
        _launcher.launch(
            plan=plan,
            superchains_params=[],
        ),
        {},
    )


def test_superchain_launcher_multiple_participants(plan):
    superchains_params = _input_parser.parse(
        {
            "superchain-0": {},
            "superchain-1": None,
            "superchain-2": {
                "participants": [2000],
            },
            "superchain-3": {
                "participants": [1000, 2000],
            },
        },
        _chains,
    )

    expect.eq(
        _launcher.launch(
            plan=plan,
            superchains_params=superchains_params,
        ),
        {
            "superchain-0": struct(
                artifact="superchain-depset-superchain-0",
                path="superchain-depset-superchain-0.json",
                superchain="superchain-0",
            ),
            "superchain-1": struct(
                artifact="superchain-depset-superchain-1",
                path="superchain-depset-superchain-1.json",
                superchain="superchain-1",
            ),
            "superchain-2": struct(
                artifact="superchain-depset-superchain-2",
                path="superchain-depset-superchain-2.json",
                superchain="superchain-2",
            ),
            "superchain-3": struct(
                artifact="superchain-depset-superchain-3",
                path="superchain-depset-superchain-3.json",
                superchain="superchain-3",
            ),
        },
    )
