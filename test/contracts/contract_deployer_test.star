contract_deployer = import_module("/src/contracts/contract_deployer.star")


def test_empty_hardforks_single_chain(plan):
    chain = struct(
        network_params=struct(
            fjord_time_offset=None,
            granite_time_offset=None,
            holocene_time_offset=None,
            isthmus_time_offset=None,
            interop_time_offset=None,
        )
    )
    schedule = contract_deployer._build_hardfork_schedule(chain)
    expect.eq(schedule, [])


def test_single_chain_with_hardforks(plan):
    chain = struct(
        network_params=struct(
            fjord_time_offset=0,
            granite_time_offset=None,
            holocene_time_offset=20,
            isthmus_time_offset=None,
            interop_time_offset=40,
        )
    )

    schedule = contract_deployer._build_hardfork_schedule(chain)

    expect.eq(
        schedule,
        [
            ("l2GenesisFjordTimeOffset", 0),
            ("l2GenesisHoloceneTimeOffset", 20),
            ("l2GenesisInteropTimeOffset", 40),
        ],
    )


def test_chain_with_all_hardforks(plan):
    chain = struct(
        network_params=struct(
            fjord_time_offset=0,
            granite_time_offset=100,
            holocene_time_offset=200,
            isthmus_time_offset=300,
            interop_time_offset=400,
        )
    )

    schedule = contract_deployer._build_hardfork_schedule(chain)

    expect.eq(
        schedule,
        [
            ("l2GenesisFjordTimeOffset", 0),
            ("l2GenesisGraniteTimeOffset", 100),
            ("l2GenesisHoloceneTimeOffset", 200),
            ("l2GenesisIsthmusTimeOffset", 300),
            ("l2GenesisInteropTimeOffset", 400),
        ],
    )


def test_build_superchain_roles(plan):
    primary_chain_id = "901"
    
    roles = contract_deployer._build_superchain_roles(primary_chain_id)
    
    expected = {
        "superchainGuardian": "`jq -r .address /network-data/l1ProxyAdmin-901.json`",
        "protocolVersionsOwner": "`jq -r .address /network-data/l1ProxyAdmin-901.json`",
        "superchainProxyAdminOwner": "`jq -r .address /network-data/l1ProxyAdmin-901.json`",
        "challenger": "`jq -r .address /network-data/challenger-901.json`",
    }
    expect.eq(roles, expected)


def test_build_global_deploy_overrides_with_prestate(plan):
    optimism_args = struct(
        op_contract_deployer_params=struct(
            overrides={"faultGameAbsolutePrestate": "0x123abc", "vmType": "CANNON"}
        )
    )
    
    (
        absolute_prestate,
        global_overrides,
    ) = contract_deployer._build_global_deploy_overrides(optimism_args)
    
    expect.eq(absolute_prestate, "0x123abc")
    expect.eq(
        global_overrides,
        {
            "dangerouslyAllowCustomDisputeParameters": True,
            "faultGameAbsolutePrestate": "0x123abc",
        },
    )


def test_build_global_deploy_overrides_without_prestate(plan):
    optimism_args = struct(
        op_contract_deployer_params=struct(overrides={"vmType": "CANNON"})
    )
    
    (
        absolute_prestate,
        global_overrides,
    ) = contract_deployer._build_global_deploy_overrides(optimism_args)
    
    expect.eq(absolute_prestate, "")
    expect.eq(global_overrides, None)


def test_build_hardfork_schedule_single_chain(plan):
    chain = struct(
        network_params=struct(
            fjord_time_offset=100,
            granite_time_offset=None,
            holocene_time_offset=200,
            isthmus_time_offset=None,
            interop_time_offset=300,
        )
    )
    
    schedule = contract_deployer._build_hardfork_schedule(chain)
    
    expect.eq(
        schedule,
        [
            ("l2GenesisFjordTimeOffset", 100),
            ("l2GenesisHoloceneTimeOffset", 200),
            ("l2GenesisInteropTimeOffset", 300),
        ],
    )


def test_build_hardfork_schedule_single_chain_no_hardforks(plan):
    chain = struct(
        network_params=struct(
            fjord_time_offset=None,
            granite_time_offset=None,
            holocene_time_offset=None,
            isthmus_time_offset=None,
            interop_time_offset=None,
        )
    )
    
    schedule = contract_deployer._build_hardfork_schedule(chain)
    
    expect.eq(schedule, [])


def test_build_chain_intent(plan):
    chain = struct(
        network_params=struct(
            network_id=901, seconds_per_slot=2, fund_dev_accounts=True
        )
    )
    chain_index = 0
    absolute_prestate = "0xabc123"
    vm_type = "CANNON"
    altda_args = struct(
        use_altda=False,
        da_commitment_type="keccak256",
        da_challenge_window=160,
        da_resolve_window=160,
        da_bond_size=1000000,
    )
    hardfork_schedule = [("l2GenesisFjordTimeOffset", 100)]
    
    intent_chain = contract_deployer._build_chain_intent(
        chain, absolute_prestate, vm_type, altda_args, hardfork_schedule
    )
    
    expect.eq(intent_chain["deployOverrides"]["l2BlockTime"], 2)
    expect.eq(intent_chain["deployOverrides"]["fundDevAccounts"], True)
    expect.eq(intent_chain["deployOverrides"]["l2GenesisFjordTimeOffset"], "0x64")
    expect.eq(
        intent_chain["baseFeeVaultRecipient"],
        "`jq -r .address /network-data/baseFeeVaultRecipient-901.json`",
    )
    expect.eq(
        intent_chain["roles"]["batcher"],
        "`jq -r .address /network-data/batcher-901.json`",
    )
    expect.eq(
        intent_chain["dangerousAdditionalDisputeGames"][0]["faultGameAbsolutePrestate"],
        "0xabc123",
    )
    expect.eq(intent_chain["dangerousAdditionalDisputeGames"][0]["vmType"], "CANNON")
    expect.eq(intent_chain["dangerousAltDAConfig"]["useAltDA"], False)


def test_build_chain_intent_no_hardforks(plan):
    chain = struct(
        network_params=struct(
            network_id=902, seconds_per_slot=1, fund_dev_accounts=False
        )
    )
    chain_index = 1
    absolute_prestate = ""
    vm_type = "ASTERISC"
    altda_args = struct(
        use_altda=True,
        da_commitment_type="generic",
        da_challenge_window=200,
        da_resolve_window=300,
        da_bond_size=2000000,
    )
    hardfork_schedule = []
    
    intent_chain = contract_deployer._build_chain_intent(
        chain, absolute_prestate, vm_type, altda_args, hardfork_schedule
    )
    
    expect.eq(intent_chain["deployOverrides"]["l2BlockTime"], 1)
    expect.eq(intent_chain["deployOverrides"]["fundDevAccounts"], False)
    expect.eq(intent_chain["dangerousAdditionalDisputeGames"][0]["vmType"], "ASTERISC")
    expect.eq(intent_chain["dangerousAltDAConfig"]["useAltDA"], True)
    expect.eq(intent_chain["dangerousAltDAConfig"]["daCommitmentType"], "generic")


def test_build_deployment_intent_no_interop(plan):
    optimism_args = struct(
        superchains=[],
        chains=[
            struct(
                network_params=struct(
                    network_id=901,
                    seconds_per_slot=2,
                    fund_dev_accounts=True,
                    fjord_time_offset=None,
                    granite_time_offset=None,
                    holocene_time_offset=None,
                    isthmus_time_offset=None,
                    interop_time_offset=None,
                )
            )
        ],
        op_contract_deployer_params=struct(overrides={"vmType": "CANNON"}),
    )
    l1_artifacts_locator = "file:///artifacts/l1"
    l2_artifacts_locator = "file:///artifacts/l2"
    altda_args = struct(
        use_altda=False,
        da_commitment_type="keccak256",
        da_challenge_window=160,
        da_resolve_window=160,
        da_bond_size=1000000,
    )

    intent = contract_deployer._build_deployment_intent(
        optimism_args, l1_artifacts_locator, l2_artifacts_locator, altda_args
    )

    expect.eq(intent["useInterop"], False)
    expect.eq(intent["l1ContractsLocator"], "file:///artifacts/l1")
    expect.eq(intent["l2ContractsLocator"], "file:///artifacts/l2")
    expect.eq(len(intent["chains"]), 1)
    expect.eq(intent["chains"][0]["deployOverrides"]["l2BlockTime"], 2)
    expect.eq(intent["chains"][0]["deployOverrides"]["fundDevAccounts"], True)
    
    # Test that superchain roles are properly configured
    expect.eq(
        intent["superchainRoles"]["superchainGuardian"],
        "`jq -r .address /network-data/l1ProxyAdmin-901.json`",
    )
    expect.eq(
        intent["superchainRoles"]["challenger"],
        "`jq -r .address /network-data/challenger-901.json`",
    )


def test_build_deployment_intent_with_interop_and_prestate(plan):
    optimism_args = struct(
        superchains=[struct(name="superchain1")],
        chains=[
            struct(
                network_params=struct(
                    network_id=901,
                    seconds_per_slot=2,
                    fund_dev_accounts=True,
                    fjord_time_offset=100,
                    granite_time_offset=None,
                    holocene_time_offset=200,
                    isthmus_time_offset=None,
                    interop_time_offset=300,
                )
            ),
            struct(
                network_params=struct(
                    network_id=902,
                    seconds_per_slot=1,
                    fund_dev_accounts=False,
                    fjord_time_offset=None,
                    granite_time_offset=None,
                    holocene_time_offset=None,
                    isthmus_time_offset=None,
                    interop_time_offset=None,
                )
            ),
        ],
        op_contract_deployer_params=struct(
            overrides={"faultGameAbsolutePrestate": "0x123", "vmType": "ASTERISC"}
        ),
    )
    l1_artifacts_locator = "file:///artifacts/l1"
    l2_artifacts_locator = "file:///artifacts/l2"
    altda_args = struct(
        use_altda=True,
        da_commitment_type="generic",
        da_challenge_window=200,
        da_resolve_window=300,
        da_bond_size=2000000,
    )

    intent = contract_deployer._build_deployment_intent(
        optimism_args, l1_artifacts_locator, l2_artifacts_locator, altda_args
    )

    expect.eq(intent["useInterop"], True)
    expect.eq(len(intent["chains"]), 2)
    
    # Test global deploy overrides (tests _build_global_deploy_overrides indirectly)
    expect.eq(intent["globalDeployOverrides"]["faultGameAbsolutePrestate"], "0x123")
    expect.eq(intent["globalDeployOverrides"]["dangerouslyAllowCustomDisputeParameters"], True)
    
    # Test chain intent configuration
    expect.eq(intent["chains"][0]["deployOverrides"]["l2BlockTime"], 2)
    expect.eq(intent["chains"][0]["deployOverrides"]["fundDevAccounts"], True)
    expect.eq(
        intent["chains"][0]["dangerousAdditionalDisputeGames"][0]["vmType"], "ASTERISC"
    )
    expect.eq(
        intent["chains"][0]["dangerousAdditionalDisputeGames"][0]["faultGameAbsolutePrestate"], "0x123"
    )
    expect.eq(intent["chains"][1]["dangerousAltDAConfig"]["useAltDA"], True)
    expect.eq(intent["chains"][1]["dangerousAltDAConfig"]["daCommitmentType"], "generic")
    
    # Test hardfork schedule application (tests _build_hardfork_schedule indirectly)
    expect.eq(intent["chains"][0]["deployOverrides"]["l2GenesisFjordTimeOffset"], "0x64")  # 100 in hex
    expect.eq(intent["chains"][0]["deployOverrides"]["l2GenesisHoloceneTimeOffset"], "0xc8")  # 200 in hex
    expect.eq(intent["chains"][0]["deployOverrides"]["l2GenesisInteropTimeOffset"], "0x12c")  # 300 in hex


def test_build_deployment_intent_no_global_overrides(plan):
    optimism_args = struct(
        superchains=[],
        chains=[
            struct(
                network_params=struct(
                    network_id=901,
                    seconds_per_slot=2,
                    fund_dev_accounts=True,
                    fjord_time_offset=None,
                    granite_time_offset=None,
                    holocene_time_offset=None,
                    isthmus_time_offset=None,
                    interop_time_offset=None,
                )
            )
        ],
        op_contract_deployer_params=struct(overrides={"vmType": "CANNON"}),
    )
    l1_artifacts_locator = "file:///artifacts/l1"
    l2_artifacts_locator = "file:///artifacts/l2"
    altda_args = struct(
        use_altda=False,
        da_commitment_type="keccak256",
        da_challenge_window=160,
        da_resolve_window=160,
        da_bond_size=1000000,
    )

    intent = contract_deployer._build_deployment_intent(
        optimism_args, l1_artifacts_locator, l2_artifacts_locator, altda_args
    )

    # Test that no global deploy overrides are set when there's no fault game prestate
    expect.eq("globalDeployOverrides" in intent, False)


def test_build_deployment_intent_multiple_chains_different_configs(plan):
    optimism_args = struct(
        superchains=[struct(name="test")],
        chains=[
            struct(
                network_params=struct(
                    network_id=1001,
                    seconds_per_slot=3,
                    fund_dev_accounts=True,
                    fjord_time_offset=50,
                    granite_time_offset=None,
                    holocene_time_offset=None,
                    isthmus_time_offset=None,
                    interop_time_offset=None,
                )
            ),
            struct(
                network_params=struct(
                    network_id=1002,
                    seconds_per_slot=1,
                    fund_dev_accounts=False,
                    fjord_time_offset=None,
                    granite_time_offset=75,
                    holocene_time_offset=None,
                    isthmus_time_offset=None,
                    interop_time_offset=125,
                )
            ),
        ],
        op_contract_deployer_params=struct(overrides={"vmType": "CANNON"}),
    )
    l1_artifacts_locator = "file:///artifacts/l1"
    l2_artifacts_locator = "file:///artifacts/l2"
    altda_args = struct(
        use_altda=False,
        da_commitment_type="keccak256",
        da_challenge_window=160,
        da_resolve_window=160,
        da_bond_size=1000000,
    )

    intent = contract_deployer._build_deployment_intent(
        optimism_args, l1_artifacts_locator, l2_artifacts_locator, altda_args
    )

    expect.eq(intent["useInterop"], True)
    expect.eq(len(intent["chains"]), 2)
    
    # Test first chain configuration
    expect.eq(intent["chains"][0]["deployOverrides"]["l2BlockTime"], 3)
    expect.eq(intent["chains"][0]["deployOverrides"]["fundDevAccounts"], True)
    expect.eq(intent["chains"][0]["deployOverrides"]["l2GenesisFjordTimeOffset"], "0x32")  # 50 in hex
    
    # Test second chain configuration
    expect.eq(intent["chains"][1]["deployOverrides"]["l2BlockTime"], 1)
    expect.eq(intent["chains"][1]["deployOverrides"]["fundDevAccounts"], False)
    expect.eq(intent["chains"][1]["deployOverrides"]["l2GenesisGraniteTimeOffset"], "0x4b")  # 75 in hex
    expect.eq(intent["chains"][1]["deployOverrides"]["l2GenesisInteropTimeOffset"], "0x7d")  # 125 in hex
