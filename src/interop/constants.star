constants = import_module("../package_io/constants.star")
util = import_module("../util.star")

INTEROP_WS_PORT_ID = "interop-ws"
INTEROP_WS_PORT_NUM = 9645

SUPERVISOR_SERVICE_NAME = "op-supervisor"
SUPERVISOR_RPC_PORT_NUM = 8545

SUPERVISOR_ENDPOINT = util.make_http_url(
    SUPERVISOR_SERVICE_NAME, SUPERVISOR_RPC_PORT_NUM
)
