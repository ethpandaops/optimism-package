ethereum_package = import_module("github.com/ethpandaops/ethereum-package/main.star")
contract_deployer = import_module("./src/contracts/contract_deployer.star")
_l2_launcher = import_module("./src/l2/launcher.star")
_l2_launcher__hack = import_module("./src/l2/launcher__hack.star")
superchain_launcher = import_module("./src/superchain/launcher.star")
supervisor_launcher = import_module("./src/supervisor/launcher.star")
op_challenger_launcher = import_module("./src/challenger/op-challenger/launcher.star")
op_test_sequencer_launcher = import_module(
    "./src/test-sequencer/op-test-sequencer/launcher.star"
)

faucet = import_module("./src/faucet/op-faucet/op_faucet_launcher.star")
interop_mon = import_module("./src/interop-mon/op-interop-mon/launcher.star")
observability = import_module("./src/observability/observability.star")
util = import_module("./src/util.star")

_net = import_module("./src/util/net.star")

wait_for_sync = import_module("./src/wait/wait_for_sync.star")
input_parser = import_module("./src/package_io/input_parser.star")
ethereum_package_static_files = import_module(
    "github.com/ethpandaops/ethereum-package/src/static_files/static_files.star"
)

_registry = import_module("./src/package_io/registry.star")


def run(plan, args={}):
    """Deploy Optimism L2s on an Ethereum L1.

    Args:
        args(json): Configures other aspects of the environment.
    Returns:
        A full deployment of Optimism L2(s)
    """
    pinned_images = args.get("registry", {})
    registry = _registry.Registry(pinned_images)

    plan.print("Parsing the L1 input args")
    # If no args are provided, use the default values with minimal preset
    ethereum_args = args.get("ethereum_package", {})
    external_l1_args = args.get("external_l1_network_params", {})
    if external_l1_args:
        external_l1_args = input_parser.external_l1_network_params_input_parser(
            plan, external_l1_args
        )
    else:
        if "network_params" not in ethereum_args:
            ethereum_args.update(input_parser.default_ethereum_package_network_params())

    optimism_args = input_parser.input_parser(
        plan=plan,
        input_args=args.get("optimism_package", {}),
        registry=registry,
    )

    global_tolerations = optimism_args.global_tolerations
    global_node_selectors = optimism_args.global_node_selectors
    global_log_level = optimism_args.global_log_level
    persistent = optimism_args.persistent
    altda_deploy_config = optimism_args.altda_deploy_config

    observability_params = optimism_args.observability
    observability_helper = observability.make_helper(observability_params)

    # EXPERIMENT
    # 
    # Deploy an l1 with a single node and the lowest blocktime we can get

    plan.print("Deploying a ghost L1")

    ghost_l1 = ethereum_package.run(plan, {
        "participants": [
            "el_type": "geth"
        ],
        "network_params": {
            "seconds_per_slot": 1,
            "network_id": "1111111111",
        }
    })

    all_ghost_l1_participants = ghost_l1.all_participants
    ghost_l1_network_params = ghost_l1.network_params
    ghost_l1_network_id = ghost_l1.network_id
    ghost_l1_rpc_url = all_ghost_l1_participants[0].el_context.rpc_http_url
    ghost_l1_priv_key = ghost_l1.pre_funded_accounts[
        12
    ].private_key  # reserved for L2 contract deployers
    ghost_l1_config_env_vars = get_l1_config(
        all_ghost_l1_participants, ghost_l1_network_params, ghost_l1_network_id
    )
    plan.print("Waiting for ghost L1 to start up")
    wait_for_sync.wait_for_startup(plan, ghost_l1_config_env_vars)

    plan.print("Deployed a ghost L1")
    plan.print("Deploying contracts on ghost L1")

    ghost_deployment_output = contract_deployer.deploy_contracts(
        plan,
        ghost_l1_priv_key,
        ghost_l1_config_env_vars,
        optimism_args,
        "local",
        altda_deploy_config,
        key="--ghost"
    )

    # exec_recipe = ExecRecipe(
    #     command = ["geth", "dump"],
    # )

    # result = plan.exec(
    #     # A Service name designating a service that already exists inside the enclave
    #     # If it does not, a validation error will be thrown
    #     # MANDATORY
    #     service_name = "my-service",
        
    #     # The recipe that will determine the exec to be performed.
    #     # Valid values are of the following types: (ExecRecipe)
    #     # MANDATORY
    #     recipe = exec_recipe,
        
    #     # If the recipe returns a code that does not belong on this list, this instruction will fail.
    #     # OPTIONAL (Defaults to [0])
    #     acceptable_codes = [0, 1], # Here both 0 and 1 are valid codes that we want to accept and not fail the instruction
        
    #     # If False, instruction will never fail based on code (acceptable_codes will be ignored).
    #     # You can chain this call with assert to check codes after request is done.
    #     # OPTIONAL (Defaults to False)
    #     skip_code_check = False,

    #     # A human friendly description for the end user of the package
    #     # OPTIONAL (Default: Executing command on service 'SERVICE_NAME')
    #     description = "executing a command"

    # )

    # 
    # FIXME Get the L1 state
    # 
    # Retrieve storage contents from an EVM address using web3.py
    # This script fetches all storage slots for a given contract address and formats them for genesis insertion

    # Now tear down the ghost L1
    for s in plan.get_services():
        plan.remove_service(name = s.name)

    # Deploy the L1
    l1_network = ""
    if external_l1_args:
        plan.print("Using external L1")
        plan.print(external_l1_args)

        l1_rpc_url = external_l1_args.el_rpc_url
        l1_priv_key = external_l1_args.priv_key

        l1_config_env_vars = {
            "L1_RPC_KIND": external_l1_args.rpc_kind,
            "L1_RPC_URL": l1_rpc_url,
            "CL_RPC_URL": external_l1_args.cl_rpc_url,
            "L1_WS_URL": external_l1_args.el_ws_url,
            "L1_CHAIN_ID": external_l1_args.network_id,
        }

        plan.print("Waiting for network to sync")
        wait_for_sync.wait_for_sync(plan, l1_config_env_vars)
    else:
        plan.print("Deploying a local L1")
        l1 = ethereum_package.run(plan, ethereum_args)
        plan.print(l1.network_params)
        # Get L1 info
        all_l1_participants = l1.all_participants
        l1_network = "local"
        l1_network_params = l1.network_params
        l1_network_id = l1.network_id
        l1_rpc_url = all_l1_participants[0].el_context.rpc_http_url
        l1_priv_key = l1.pre_funded_accounts[
            12
        ].private_key  # reserved for L2 contract deployers
        l1_config_env_vars = get_l1_config(
            all_l1_participants, l1_network_params, l1_network_id
        )
        plan.print("Waiting for L1 to start up")
        wait_for_sync.wait_for_startup(plan, l1_config_env_vars)

    plan.print("Deployed contracts on ghost L1")
    plan.print("Deploying contracts on real L1")

    deployment_output = contract_deployer.deploy_contracts(
        plan,
        l1_priv_key,
        l1_config_env_vars,
        optimism_args,
        l1_network,
        altda_deploy_config,
    )

    plan.print("Deployed contracts on real L1")

    jwt_file = plan.upload_files(
        src=ethereum_package_static_files.JWT_PATH_FILEPATH,
        name="op_jwt_file",
    )

    # TODO We need to create the dependency sets before we launch the chains since
    # e.g. op-node now depends on the artifacts to be present
    #
    # This can easily turn into another dependency cycle which means we might have to introduce yet another layer
    # of execution whose sole purpose is to create required artifacts
    for superchain_params in optimism_args.superchains:
        superchain_launcher.launch(
            plan=plan,
            params=superchain_params,
        )

    l2s = []
    for l2_params in optimism_args.chains:
        # We filter out the supervisors applicable to this network
        l2_supervisors_params = [
            supervisor_params
            for supervisor_params in optimism_args.supervisors
            if l2_params.network_params.network_id
            in supervisor_params.superchain.participants
        ]

        l2s.append(
            _l2_launcher.launch(
                plan=plan,
                params=l2_params,
                supervisors_params=l2_supervisors_params,
                jwt_file=jwt_file,
                l1_config_env_vars=l1_config_env_vars,
                deployment_output=deployment_output,
                node_selectors=global_node_selectors,
                observability_helper=observability_helper,
                l1_rpc_url=l1_rpc_url,
                log_level=global_log_level,
                tolerations=global_tolerations,
                persistent=persistent,
            )
        )

    for supervisor_params in optimism_args.supervisors:
        supervisor_launcher.launch(
            plan=plan,
            params=supervisor_params,
            l1_config_env_vars=l1_config_env_vars,
            l2s_params=optimism_args.chains,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
        )

    for test_sequencer_params in optimism_args.test_sequencers:
        op_test_sequencer_launcher.launch(
            plan=plan,
            params=test_sequencer_params,
            l1_config_env_vars=l1_config_env_vars,
            l2s_params=optimism_args.chains,
            jwt_file=jwt_file,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
        )

    for challenger_params in optimism_args.challengers:
        op_challenger_launcher.launch(
            plan=plan,
            params=challenger_params,
            l2s_params=optimism_args.chains,
            supervisors_params=optimism_args.supervisors,
            l1_config_env_vars=l1_config_env_vars,
            deployment_output=deployment_output,
            observability_helper=observability_helper,
        )

    for index, l2_params in enumerate(optimism_args.chains):
        # We filter out the supervisors applicable to this network
        l2_supervisors_params = [
            supervisor_params
            for supervisor_params in optimism_args.supervisors
            if l2_params.network_params.network_id
            in supervisor_params.superchain.participants
        ]

        original_launcher_output__hack = l2s[index]

        _l2_launcher__hack.launch(
            original_launcher_output__hack=original_launcher_output__hack,
            plan=plan,
            params=l2_params,
            supervisors_params=l2_supervisors_params,
            jwt_file=jwt_file,
            l1_config_env_vars=l1_config_env_vars,
            deployment_output=deployment_output,
            node_selectors=global_node_selectors,
            observability_helper=observability_helper,
            l1_rpc_url=l1_rpc_url,
            log_level=global_log_level,
            tolerations=global_tolerations,
            persistent=persistent,
            registry=registry,
        )

    if optimism_args.faucet.enabled:
        _install_faucet(
            plan=plan,
            registry=registry,
            faucet_params=optimism_args.faucet,
            l1_config_env_vars=l1_config_env_vars,
            l1_priv_key=l1_priv_key,
            deployment_output=deployment_output,
            l2s=l2s,
        )

    # Launch interop monitoring
    if optimism_args.interop_mon and optimism_args.interop_mon.enabled:
        interop_mon.launch(
            plan=plan,
            params=optimism_args.interop_mon,
            image=optimism_args.interop_mon.image,
            l2s=l2s,
            observability_helper=observability_helper,
        )

    observability.launch(
        plan, observability_helper, global_node_selectors, observability_params
    )


def get_l1_config(all_l1_participants, l1_network_params, l1_network_id):
    env_vars = {}
    env_vars["L1_RPC_KIND"] = "standard"
    env_vars["WEB3_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["L1_RPC_URL"] = str(all_l1_participants[0].el_context.rpc_http_url)
    env_vars["CL_RPC_URL"] = str(all_l1_participants[0].cl_context.beacon_http_url)
    env_vars["L1_WS_URL"] = str(all_l1_participants[0].el_context.ws_url)
    env_vars["L1_CHAIN_ID"] = str(l1_network_id)
    env_vars["L1_BLOCK_TIME"] = str(l1_network_params.seconds_per_slot)
    return env_vars


def _install_faucet(
    plan,
    registry,
    faucet_params,
    l1_config_env_vars,
    l1_priv_key,
    deployment_output,
    l2s,
):
    faucets = [
        faucet.faucet_data(
            name="l1",
            chain_id=l1_config_env_vars["L1_CHAIN_ID"],
            el_rpc=l1_config_env_vars["L1_RPC_URL"],
            private_key=l1_priv_key,
        ),
    ]
    for l2 in l2s:
        chain_id = l2.network_id

        private_key = util.read_network_config_value(
            plan,
            deployment_output,
            "wallets",
            '."{0}" | .["l2FaucetPrivateKey"]'.format(chain_id),
        )
        faucets.append(
            faucet.faucet_data(
                name=l2.name,
                chain_id=chain_id,
                el_rpc=l2.participants[0].el.context.rpc_http_url,
                private_key=private_key,
            )
        )

    faucet.launch(
        plan,
        "op-faucet",
        faucet_params.image or registry.get(_registry.OP_FAUCET),
        faucets,
    )
