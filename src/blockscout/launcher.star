_postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

_net = import_module("/src/util/net.star")
_util = import_module("/src/util.star")

BLOCKSCOUT_MIN_CPU = 100
BLOCKSCOUT_MAX_CPU = 1000
BLOCKSCOUT_MIN_MEMORY = 1024
BLOCKSCOUT_MAX_MEMORY = 2048

BLOCKSCOUT_VERIF_MIN_CPU = 10
BLOCKSCOUT_VERIF_MAX_CPU = 1000
BLOCKSCOUT_VERIF_MIN_MEMORY = 10
BLOCKSCOUT_VERIF_MAX_MEMORY = 1024


def launch(
    plan,
    params,
    network_params,
    l2_rpc_url,
    l1_rpc_url,
    deployment_output,
):
    network_id = network_params.network_id
    network_name = network_params.name

    rollup_filename = "rollup-{0}".format(network_id)
    portal_address = _util.read_network_config_value(
        plan, deployment_output, rollup_filename, ".deposit_contract_address"
    )
    l1_deposit_start_block = _util.read_network_config_value(
        plan, deployment_output, rollup_filename, ".genesis.l1.number"
    )

    postgres_output = _postgres.run(
        plan,
        service_name=params.database.service_name,
        database="blockscout",
        extra_configs=["max_connections=1000"],
    )

    verif_config = get_config_verif(verifier_params=params.verifier)
    verif_service = plan.add_service(params.verifier.service_name, verif_config)
    verif_url = "http://{}:{}".format(
        verif_service.hostname, verif_service.ports["http"].number
    )

    config_backend = get_config_backend(
        blockscout_params=params.blockscout,
        postgres_output=postgres_output,
        l1_rpc_url=l1_rpc_url,
        l2_rpc_url=l2_rpc_url,
        verif_url=verif_url,
        network_name=network_name,
        {
            "INDEXER_OPTIMISM_L1_PORTAL_CONTRACT": portal_address,
            "INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK": l1_deposit_start_block,
            "INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK": l1_deposit_start_block,
            "INDEXER_OPTIMISM_L1_BATCH_START_BLOCK": l1_deposit_start_block,
            # The L2OO is no longer deployed
            "INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT": "0x0000000000000000000000000000000000000000",
        },
    )
    blockscout_service = plan.add_service(
        params.blockscout.service_name, config_backend
    )

    blockscout_url = "http://{}:{}".format(
        blockscout_service.hostname, blockscout_service.ports["http"].number
    )

    return blockscout_url


def get_config_verif(verifier_params):
    return ServiceConfig(
        image=verifier_params.image,
        ports=_net.ports_to_port_specs(verifier_params.ports),
        labels=verifier_params.labels,
        env_vars={
            "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(
                verifier_params.ports[_net.HTTP_PORT_NAME].number
            )
        },
        min_cpu=BLOCKSCOUT_VERIF_MIN_CPU,
        max_cpu=BLOCKSCOUT_VERIF_MAX_CPU,
        min_memory=BLOCKSCOUT_VERIF_MIN_MEMORY,
        max_memory=BLOCKSCOUT_VERIF_MAX_MEMORY,
    )


def get_config_backend(
    blockscout_params,
    postgres_output,
    l1_rpc_url,
    l2_rpc_url,
    verif_url,
    network_name,
    additional_env_vars,
):
    database_url = "{protocol}://{user}:{password}@{hostname}:{port}/{database}".format(
        protocol="postgresql",
        user=postgres_output.user,
        password=postgres_output.password,
        hostname=postgres_output.service.hostname,
        port=postgres_output.port.number,
        database=postgres_output.database,
    )

    optimism_env_vars = {
        "CHAIN_TYPE": "optimism",
        "INDEXER_OPTIMISM_L1_RPC": l1_rpc_url,
        # "INDEXER_OPTIMISM_L1_PORTAL_CONTRACT": "",
        # "INDEXER_OPTIMISM_L1_BATCH_START_BLOCK": "",
        "INDEXER_OPTIMISM_L1_BATCH_INBOX": "0xff00000000000000000000000000000000042069",
        "INDEXER_OPTIMISM_L1_BATCH_SUBMITTER": "0x776463f498A63a42Ac1AFc7c64a4e5A9ccBB4d32",
        "INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL": verif_url + "/blobs",
        "INDEXER_OPTIMISM_L1_BATCH_BLOCKS_CHUNK_SIZE": "4",
        "INDEXER_OPTIMISM_L2_BATCH_GENESIS_BLOCK_NUMBER": "0",
        "INDEXER_OPTIMISM_L1_OUTPUT_ROOTS_START_BLOCK": "0",
        # "INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT": l2oo_address,
        # "INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK": l1_deposit_start_block,
        "INDEXER_OPTIMISM_L1_DEPOSITS_BATCH_SIZE": "500",
        # "INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK": l1_deposit_start_block,
        "INDEXER_OPTIMISM_L2_WITHDRAWALS_START_BLOCK": "1",
        "INDEXER_OPTIMISM_L2_MESSAGE_PASSER_CONTRACT": "0xC0D3C0d3C0d3c0d3C0d3C0D3c0D3c0d3c0D30016",
    } | additional_env_vars

    return ServiceConfig(
        image=blockscout_params.image,
        ports=_net.ports_to_port_specs(blockscout_params.ports),
        labels=blockscout_params.labels,
        cmd=[
            "/bin/sh",
            "-c",
            'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start',
        ],
        env_vars={
            "ETHEREUM_JSONRPC_VARIANT": "geth",
            "ETHEREUM_JSONRPC_HTTP_URL": l2_rpc_url,
            "ETHEREUM_JSONRPC_TRACE_URL": l2_rpc_url,
            "DATABASE_URL": database_url,
            "COIN": "opETH",
            "MICROSERVICE_SC_VERIFIER_ENABLED": "true",
            "MICROSERVICE_SC_VERIFIER_URL": verif_url,
            "MICROSERVICE_SC_VERIFIER_TYPE": "sc_verifier",
            "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
            "ECTO_USE_SSL": "false",
            "NETWORK": network_name,
            "SUBNETWORK": network_name,
            "API_V2_ENABLED": "true",
            "PORT": "{}".format(blockscout_params.ports[_net.HTTP_PORT_NAME].number),
            "SECRET_KEY_BASE": "56NtB48ear7+wMSf0IQuWDAAazhpb31qyc7GiyspBP2vh7t5zlCsF5QDv76chXeN",
        }
        | optimism_env_vars,
        min_cpu=BLOCKSCOUT_MIN_CPU,
        max_cpu=BLOCKSCOUT_MAX_CPU,
        min_memory=BLOCKSCOUT_MIN_MEMORY,
        max_memory=BLOCKSCOUT_MAX_MEMORY,
    )
