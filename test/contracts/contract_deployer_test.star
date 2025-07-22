contract_deployer = import_module("/src/contracts/contract_deployer.star")


def test_empty_chains(plan):
    schedule = contract_deployer.build_hardfork_schedule([])
    expect.eq(schedule, [])


def test_single_chain_with_hardforks(plan):
    chains = [struct(network_params=struct(
        fjord_time_offset=0,
        granite_time_offset=None,
        holocene_time_offset=20,
        isthmus_time_offset=None,
        interop_time_offset=40,
    ))]
    
    schedule = contract_deployer.build_hardfork_schedule(chains)
    
    expect.eq(schedule, [
        (0, "l2GenesisFjordTimeOffset", 0),
        (0, "l2GenesisHoloceneTimeOffset", 20),
        (0, "l2GenesisInteropTimeOffset", 40),
    ])


def test_multiple_chains_different_interop_offsets(plan):
    chains = [
        struct(network_params=struct(
            fjord_time_offset=0,
            granite_time_offset=0,
            holocene_time_offset=None,
            isthmus_time_offset=None,
            interop_time_offset=100,
        )),
        struct(network_params=struct(
            fjord_time_offset=0,
            granite_time_offset=0,
            holocene_time_offset=None,
            isthmus_time_offset=None,
            interop_time_offset=5000,
        ))
    ]
    
    schedule = contract_deployer.build_hardfork_schedule(chains)
    
    expect.eq(schedule, [
        (0, "l2GenesisFjordTimeOffset", 0),
        (0, "l2GenesisGraniteTimeOffset", 0),
        (0, "l2GenesisInteropTimeOffset", 100),
        (1, "l2GenesisFjordTimeOffset", 0),
        (1, "l2GenesisGraniteTimeOffset", 0),
        (1, "l2GenesisInteropTimeOffset", 5000),
    ]) 