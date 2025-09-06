_filter = import_module("/src/util/filter.star")
_file = import_module("/src/util/file.star")
_net = import_module("/src/util/net.star")
_util = import_module("/src/util.star")


_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_observability = import_module("/src/observability/observability.star")
_prometheus = import_module("/src/observability/prometheus/prometheus_launcher.star")


DATA_DIR = "/etc/op-supervisor"
DATA_FILE = "/data/sv2.json"


def launch(
    plan,
    params,
    l1_config_env_vars,
    l2s_params,
    jwt_file,
    deployment_output,
    observability_helper,
):
    supervisor_l2s_params = [
        l2_params
        for l2_params in l2s_params
        if l2_params.network_params.network_id in params.superchain.participants
    ]

    sv2_config = _generate_sv2_config(plan, params, supervisor_l2s_params, l1_config_env_vars)

    # Create SV2 config file artifact with proper chain data
    # Use write_to_file since Starlark templates can't handle complex JSON structures
    chains_json = []
    for chain in sv2_config.config["chains"]:
        chain_json = '''{
  "l1_rpc": "%s",
  "beacon_addr": "%s",
  "l2_authrpc": "%s",
  "l2_userrpc": "%s",
  "jwt_secret": "%s",
  "rollup_config": "%s",
  "user_rpc_listen_addr": "%s",
  "user_rpc_port": %d
}''' % (
            chain["l1_rpc"],
            chain["beacon_addr"],
            chain["l2_authrpc"],
            chain["l2_userrpc"],
            chain["jwt_secret"],
            chain["rollup_config"],
            chain["user_rpc_listen_addr"],
            chain["user_rpc_port"]
        )
        chains_json.append(chain_json)

    sv2_json_content = '''{
  "chains": [
%s
  ]
}''' % ",\n".join(chains_json)

    sv2_config_file = _util.write_to_file(
        plan=plan,
        contents=sv2_json_content,
        directory="/tmp",
        file_name="sv2.json"
    )

    # Need to add all the ports
    for port_spec in sv2_config.ports_per_participant:
        port = sv2_config.ports_per_participant[port_spec]
        # Port names must adhere to the RFC 6335 standard, specifically implementing this regex and be 1-15 characters long: ^[a-z]([-a-z0-9]{0,13}[a-z0-9])?$
        params.ports["rpc-v2-{}".format(port)] = _net.port(number=int(port))

    config = _get_config(
        plan=plan,
        params=params,
        l1_config_env_vars=l1_config_env_vars,
        l2s_params=supervisor_l2s_params,
        jwt_file=jwt_file,
        deployment_output=deployment_output,
        observability_helper=observability_helper,
        sv2_config_file=sv2_config_file,
    )

    service = plan.add_service(params.service_name, config)

    return struct(service=service, l2s=supervisor_l2s_params, config_per_network=sv2_config)


def _get_config(
    plan,
    params,
    l1_config_env_vars,
    l2s_params,
    jwt_file,
    deployment_output,
    observability_helper,
    sv2_config_file,
):
    ports = _net.ports_to_port_specs(params.ports)

    cmd = [
        "op-supervisor-v2",
        "--sv2.config={}".format(DATA_FILE),
        "--http.addr=0.0.0.0",
        "--http.port={0}".format(ports[_net.RPC_PORT_NAME].number),
        "--sv2.data-dir={}".format(DATA_DIR),
        "--poll.interval=1s",
        "--confirm.depth=15",
        #"--log-level=debug",
    ] + params.extra_params

    #if params.opnode_proxy:
    cmd.append("--proxy.opnode")

    env_vars = {
        "SV2_SEQUENCER_ENABLED": "true",
        "SV2_L1_SCOPE": "safe", # safe/unsafe/finalized
    }

    # apply customizations
    if params.pprof_enabled:
        _observability.configure_op_service_pprof(cmd, ports)

    return ServiceConfig(
        image=params.image,
        ports=ports,
        labels=params.labels,
        files={
            "/data": sv2_config_file,
            _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS: deployment_output,
            _ethereum_package_constants.JWT_MOUNTPOINT_ON_CLIENTS: jwt_file,
        },
        env_vars=env_vars,
        cmd=cmd,
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )


def _generate_sv2_config(plan, params, l2s_params, l1_config_env_vars):
    """Generate SV2 configuration JSON."""

    # Find chain configurations for the chains SV2 should manage
    sv2_chains = []
    ports_per_chain = {}
    user_rpc_port = 9701
    # l2s_params is a list of L2 parameter objects, iterate over each one
    for l2_param in l2s_params:
        for participant in l2_param.participants:
            participant_key = "{}-{}".format(l2_param.network_params.network_id, participant.name)
            plan.print("User RPC port for participant {}: {}".format(participant_key, user_rpc_port))
            ports_per_chain[participant_key] = "{}".format(user_rpc_port)
            # Build chain config for SV2
            chain_cfg = {
                "l1_rpc": l1_config_env_vars["L1_RPC_URL"],
                "beacon_addr": l1_config_env_vars["CL_RPC_URL"],
                "l2_authrpc": _net.service_url(
                                participant.el.service_name,
                                participant.el.ports[_net.ENGINE_RPC_PORT_NAME],
                            ),
                "l2_userrpc": _net.service_url(
                                participant.el.service_name,
                                participant.el.ports[_net.RPC_PORT_NAME],
                            ),
                "jwt_secret": _ethereum_package_constants.JWT_MOUNT_PATH_ON_CONTAINER,
                "rollup_config": _ethereum_package_constants.GENESIS_DATA_MOUNTPOINT_ON_CLIENTS
                + "/rollup-{}.json".format(l2_param.network_params.network_id),
                "user_rpc_listen_addr": "0.0.0.0",
                "user_rpc_port": user_rpc_port,
                # "p2p_static": [],
                # "p2p_bootnodes": [],
                # "p2p_peerstore_path": "",
                # "p2p_discovery_path": ""
            }
            sv2_chains.append(chain_cfg)
            user_rpc_port += 1
    # Build complete SV2 config
    config = {
        "chains": sv2_chains,
    }
    
    return struct(
        config=config,
        ports_per_participant=ports_per_chain,
    )
