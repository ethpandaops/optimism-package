util = import_module("../util.star")

INTEROP_WS_PORT_ID = "interop-ws"
INTEROP_WS_PORT_NUM = 9645

SUPERVISOR_SERVICE_NAME = "op-supervisor"
SUPERVISOR_RPC_PORT_NUM = 8545

# FIXME This endpoint no longer exists and its usages should be dropped
SUPERVISOR_ENDPOINT = util.make_http_url(
    SUPERVISOR_SERVICE_NAME, SUPERVISOR_RPC_PORT_NUM
)
