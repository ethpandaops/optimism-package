el_cl_launcher = import_module("/src/el_cl_launcher.star")
input_parser = import_module("/src/package_io/input_parser.star")
observability = import_module("/src/observability/observability.star")
ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)
util = import_module("/src/util.star")

def test_launch_with_defaults(plan):
    parsed_input_args = input_parser.input_parser(plan, {
        "chains": [{
            "participants": [{
                "el_type": "op-reth",
                "el_image": "op-reth:latest",
                "cl_type": "op-node",
                "cl_image": "op-node:latest",
            }]
        }]
    })

    observability_helper = observability.make_helper(parsed_input_args.observability)

    deployment_output = "/path/to/deployment_output"
    l1_config_env_vars = {
        "L1_RPC_URL": "L1_RPC_URL",
        "L1_RPC_KIND": "standard",
        "CL_RPC_URL": "CL_RPC_URL",
    }
    jwt_file = "/path/to/jwt_file"
    chains = parsed_input_args.chains
    chain = chains[0]
    da_server_context = struct(
        enabled = False,
        http_url = "da_server_http_url",
    )

    # We'll mock read_network_config_value since it returns a runtime value that we would not be able to retrieve
    sequencer_private_key_mock = "sequencer_private_key"
    read_network_config_value_mock = kurtestosis.mock(util, "read_network_config_value").mock_return_value(sequencer_private_key_mock)

    all_el_contexts, all_cl_contexts = el_cl_launcher.launch(
        plan = plan,
        jwt_file = jwt_file,
        network_params = chain.network_params,
        mev_params = chain.mev_params,
        deployment_output = deployment_output,
        participants = chain.participants,
        num_participants = len(chains),
        l1_config_env_vars = l1_config_env_vars,
        l2_services_suffix = "",
        global_log_level = "info",
        global_node_selectors = [],
        global_tolerations = [],
        persistent = False,
        additional_services = [],
        observability_helper = observability_helper,
        interop_params = parsed_input_args.interop,
        da_server_context = da_server_context,
    )

    el_service_name = "op-el-1-op-reth-op-node-"
    el_sevice = plan.get_service(el_service_name)

    cl_service_config = kurtestosis.get_service_config(service_name = "op-cl-1-op-node-op-reth-")
    expect.ne(cl_service_config, None)
    expect.eq(cl_service_config.image, "op-node:latest")
    expect.eq(cl_service_config.env_vars, {})
    expect.eq(cl_service_config.cmd, [
        "op-node", 
        "--l2=http://{0}:{1}".format(el_sevice.ip_address, el_sevice.ports["engine-rpc"].number), 
        "--l2.jwt-secret=/jwt/jwtsecret", 
        "--verifier.l1-confs=1", 
        "--rollup.config=/network-configs/rollup-{0}.json".format(chain.network_params.network_id), 
        "--rpc.addr=0.0.0.0", 
        "--rpc.port=8547", 
        "--rpc.enable-admin", 
        "--l1={0}".format(l1_config_env_vars["L1_RPC_URL"]),
        "--l1.rpckind={0}".format(l1_config_env_vars["L1_RPC_KIND"]), 
        "--l1.beacon={0}".format(l1_config_env_vars["CL_RPC_URL"]), 
        "--p2p.advertise.ip={0}".format(ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER), 
        "--p2p.advertise.tcp=9003", 
        "--p2p.advertise.udp=9003", 
        "--p2p.listen.ip=0.0.0.0", 
        "--p2p.listen.tcp=9003", 
        "--p2p.listen.udp=9003", 
        "--safedb.path=/data/op-node/op-node-beacon-data", 
        "--altda.enabled={0}".format(da_server_context.enabled), 
        "--altda.da-server={0}".format(da_server_context.http_url), 
        "--metrics.enabled=true", 
        "--metrics.addr=0.0.0.0", 
        "--metrics.port=9001", 
        "--p2p.sequencer.key={0}".format(sequencer_private_key_mock), 
        "--sequencer.enabled", 
        "--sequencer.l1-confs=2"
    ])

    el_service_config = kurtestosis.get_service_config(service_name = "op-el-1-op-reth-op-node-")
    expect.ne(el_service_config, None)
    expect.eq(el_service_config.image, "op-reth:latest")
    expect.eq(el_service_config.env_vars, {})
    expect.eq(el_service_config.cmd, [
        "node", 
        "--datadir=/data/op-reth/execution-data", 
        "--chain=/network-configs/genesis-{0}.json".format(chain.network_params.network_id), 
        "--http", 
        "--http.port=8545", 
        "--http.addr=0.0.0.0", 
        "--http.corsdomain=*", 
        "--http.api=admin,net,eth,web3,debug,trace", 
        "--ws", 
        "--ws.addr=0.0.0.0", 
        "--ws.port=8546", 
        "--ws.api=net,eth", 
        "--ws.origins=*", 
        "--nat=extip:{0}".format(ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER), 
        "--authrpc.port={0}".format(el_sevice.ports["engine-rpc"].number), 
        "--authrpc.jwtsecret=/jwt/jwtsecret", 
        "--authrpc.addr=0.0.0.0", 
        "--discovery.port=30303", 
        "--port=30303", 
        "--rpc.eth-proof-window=302400", 
        "--metrics=0.0.0.0:9001"
    ])