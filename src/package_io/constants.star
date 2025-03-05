NETWORK_NAME = "kurtosis"

HTTP_PORT_ID = "http"
RPC_PORT_ID = "rpc"
WS_PORT_ID = "ws"
TCP_DISCOVERY_PORT_ID = "tcp-discovery"
UDP_DISCOVERY_PORT_ID = "udp-discovery"
ENGINE_RPC_PORT_ID = "engine-rpc"
ENGINE_WS_PORT_ID = "engineWs"

EL_TYPE = struct(
    op_geth="op-geth",
    op_erigon="op-erigon",
    op_nethermind="op-nethermind",
    op_besu="op-besu",
    op_reth="op-reth",
)

CL_TYPE = struct(
    op_node="op-node",
    hildr="hildr",
)

CLIENT_TYPES = struct(
    el="execution",
    cl="beacon",
)
VOLUME_SIZE = {
    "kurtosis": {
        "op_geth_volume_size": 5000,  # 5GB
        "op_erigon_volume_size": 3000,  # 3GB
        "op_nethermind_volume_size": 3000,  # 3GB
        "op_besu_volume_size": 3000,  # 3GB
        "op_reth_volume_size": 3000,  # 3GB
        "op_node_volume_size": 1000,  # 1GB
        "hildr_volume_size": 1000,  # 1GB
    },
}
