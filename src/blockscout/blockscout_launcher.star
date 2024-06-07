shared_utils = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/shared_utils/shared_utils.star"
)
constants = import_module(
    "github.com/kurtosis-tech/ethereum-package/src/package_io/constants.star"
)

postgres = import_module("github.com/kurtosis-tech/postgres-package/main.star")

IMAGE_NAME_BLOCKSCOUT = "blockscout/blockscout:6.6.0"
IMAGE_NAME_BLOCKSCOUT_VERIF = "ghcr.io/blockscout/smart-contract-verifier:v1.6.0"

SERVICE_NAME_BLOCKSCOUT = "op-blockscout"

HTTP_PORT_ID = "http"
HTTP_PORT_NUMBER = 4000
HTTP_PORT_NUMBER_VERIF = 8050

BLOCKSCOUT_MIN_CPU = 100
BLOCKSCOUT_MAX_CPU = 1000
BLOCKSCOUT_MIN_MEMORY = 1024
BLOCKSCOUT_MAX_MEMORY = 2048

BLOCKSCOUT_VERIF_MIN_CPU = 10
BLOCKSCOUT_VERIF_MAX_CPU = 1000
BLOCKSCOUT_VERIF_MIN_MEMORY = 10
BLOCKSCOUT_VERIF_MAX_MEMORY = 1024

USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}

VERIF_USED_PORTS = {
    HTTP_PORT_ID: shared_utils.new_port_spec(
        HTTP_PORT_NUMBER_VERIF,
        shared_utils.TCP_PROTOCOL,
        shared_utils.HTTP_APPLICATION_PROTOCOL,
    )
}


def launch_blockscout(
    plan,
    el_context,
):
    postgres_output = postgres.run(
        plan,
        service_name="{0}-postgres".format(SERVICE_NAME_BLOCKSCOUT),
        database="blockscout",
        extra_configs=["max_connections=1000"],
    )

    config_verif = get_config_verif()
    verif_service_name = "{}-verif".format(SERVICE_NAME_BLOCKSCOUT)
    verif_service = plan.add_service(verif_service_name, config_verif)
    verif_url = "http://{}:{}/api".format(
        verif_service.hostname, verif_service.ports["http"].number
    )

    config_backend = get_config_backend(
        postgres_output,
        el_context,
        verif_url,
    )
    blockscout_service = plan.add_service(SERVICE_NAME_BLOCKSCOUT, config_backend)
    plan.print(blockscout_service)

    blockscout_url = "http://{}:{}".format(
        blockscout_service.hostname, blockscout_service.ports["http"].number
    )

    return blockscout_url


def get_config_verif():
    return ServiceConfig(
        image=IMAGE_NAME_BLOCKSCOUT_VERIF,
        ports=VERIF_USED_PORTS,
        env_vars={
            "SMART_CONTRACT_VERIFIER__SERVER__HTTP__ADDR": "0.0.0.0:{}".format(
                HTTP_PORT_NUMBER_VERIF
            )
        },
        min_cpu=BLOCKSCOUT_VERIF_MIN_CPU,
        max_cpu=BLOCKSCOUT_VERIF_MAX_CPU,
        min_memory=BLOCKSCOUT_VERIF_MIN_MEMORY,
        max_memory=BLOCKSCOUT_VERIF_MAX_MEMORY,
    )


def get_config_backend(postgres_output, el_context, verif_url):
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
        "INDEXER_OPTIMISM_L1_RPC": el_context.rpc_http_url,
        "INDEXER_OPTIMISM_L1_PORTAL_CONTRACT": "",
        "INDEXER_OPTIMISM_L1_BATCH_START_BLOCK": "",
        "INDEXER_OPTIMISM_L1_BATCH_INBOX": "0xff00000000000000000000000000000000042069",
        "INDEXER_OPTIMISM_L1_BATCH_SUBMITTER": "0x776463f498A63a42Ac1AFc7c64a4e5A9ccBB4d32",
        "INDEXER_OPTIMISM_L1_BATCH_BLOCKSCOUT_BLOBS_API_URL": verif_url + "/blobs",
        "INDEXER_OPTIMISM_L1_BATCH_BLOCKS_CHUNK_SIZE": "4",
        "INDEXER_OPTIMISM_L2_BATCH_GENESIS_BLOCK_NUMBER": "",
        "INDEXER_OPTIMISM_L1_OUTPUT_ROOTS_START_BLOCK": "",
        "INDEXER_OPTIMISM_L1_OUTPUT_ORACLE_CONTRACT": "",
        "INDEXER_OPTIMISM_L1_DEPOSITS_START_BLOCK": "",
        "INDEXER_OPTIMISM_L1_DEPOSITS_BATCH_SIZE": "500",
        "INDEXER_OPTIMISM_L1_WITHDRAWALS_START_BLOCK": "",
        "INDEXER_OPTIMISM_L2_WITHDRAWALS_START_BLOCK": "",
        "INDEXER_OPTIMISM_L2_MESSAGE_PASSER_CONTRACT": "",
    }

    return ServiceConfig(
        image=IMAGE_NAME_BLOCKSCOUT,
        ports=USED_PORTS,
        cmd=[
            "/bin/sh",
            "-c",
            'bin/blockscout eval "Elixir.Explorer.ReleaseTasks.create_and_migrate()" && bin/blockscout start',
        ],
        env_vars={
            "ETHEREUM_JSONRPC_VARIANT": "erigon"
            if el_context.client_name == "erigon" or el_context.client_name == "reth"
            else el_context.client_name,
            "ETHEREUM_JSONRPC_HTTP_URL": el_context.rpc_http_url,
            "ETHEREUM_JSONRPC_TRACE_URL": el_context.rpc_http_url,
            "DATABASE_URL": database_url,
            "COIN": "opETH",
            "MICROSERVICE_SC_VERIFIER_ENABLED": "true",
            "MICROSERVICE_SC_VERIFIER_URL": verif_url,
            "MICROSERVICE_SC_VERIFIER_TYPE": "sc_verifier",
            "INDEXER_DISABLE_PENDING_TRANSACTIONS_FETCHER": "true",
            "ECTO_USE_SSL": "false",
            "NETWORK": "Kurtosis",
            "SUBNETWORK": "Kurtosis",
            "API_V2_ENABLED": "true",
            "PORT": "{}".format(HTTP_PORT_NUMBER),
            "SECRET_KEY_BASE": "56NtB48ear7+wMSf0IQuWDAAazhpb31qyc7GiyspBP2vh7t5zlCsF5QDv76chXeN",
        }
        | optimism_env_vars,
        min_cpu=BLOCKSCOUT_MIN_CPU,
        max_cpu=BLOCKSCOUT_MAX_CPU,
        min_memory=BLOCKSCOUT_MIN_MEMORY,
        max_memory=BLOCKSCOUT_MAX_MEMORY,
    )
