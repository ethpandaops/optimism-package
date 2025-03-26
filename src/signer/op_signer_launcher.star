ethereum_package_shared_utils = import_module(
    "github.com/ethpandaops/ethereum-package/src/shared_utils/shared_utils.star"
)

ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

constants = import_module("../package_io/constants.star")
util = import_module("../util.star")

observability = import_module("../observability/observability.star")

SERVICE_TYPE = "signer"
SERVICE_NAME = util.make_op_service_name(SERVICE_TYPE)

# Port nums
HTTP_PORT_NUM = 8545

TEMPLATES_FILEPATH = "./templates"

CONFIG_FILE_NAME = "config.yaml"
CONFIG_TEMPLATE_FILEPATH = "{0}/{1}.tmpl".format(TEMPLATES_FILEPATH, CONFIG_FILE_NAME)

GENERATE_CREDS_DIR = "/creds"
TLS_DIR = "/tls"
CONFIG_DIRPATH_ON_SERVICE = "/config"
CLIENT_KEY_DIRPATH_ON_SERVICE = "/keys"

def get_used_ports():
    used_ports = {
        constants.HTTP_PORT_ID: ethereum_package_shared_utils.new_port_spec(
            HTTP_PORT_NUM,
            ethereum_package_shared_utils.TCP_PROTOCOL,
            ethereum_package_shared_utils.HTTP_APPLICATION_PROTOCOL,
        ),
    }
    return used_ports


def launch(
    plan,
    signer_params,
    network_params,
    clients,
    observability_helper,
):
    service_instance_name = util.make_service_instance_name(SERVICE_NAME, network_params)

    tls_artifact = create_tls_artifact(
        plan,
        service_instance_name,
    )

    client_key_artifacts = create_key_artifacts(
        plan,
        service_instance_name,
        clients,
    )

    config_artifact_name = create_config_artifact(
        plan,
        service_instance_name,
        client_key_artifacts,
        observability_helper,
    )

    service = plan.add_service(service_instance_name, make_service_config(
        plan,
        signer_params,
        tls_artifact,
        config_artifact_name,
        client_key_artifacts,
        observability_helper,
    ))

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service

def create_tls_artifact(
    plan,
    service_instance_name,
):
    return generate_credentials(
        plan,
        ["ca"],
        [StoreSpec(
            src=GENERATE_CREDS_DIR,
            name="{0}-tls".format(service_instance_name)
        )],
    )[0]

def create_key_artifacts(
    plan,
    service_instance_name,
    clients,
):
    client_key_artifacts = {}

    for client_name, client in clients.items():
        file_name = "{0}_key.pem".format(client_name)
        der_file = "ec_key.der"
        
        cmds = [
            "mkdir {0}".format(CLIENT_KEY_DIRPATH_ON_SERVICE),
            "cd {0}".format(CLIENT_KEY_DIRPATH_ON_SERVICE),
            # convert raw hex private key to binary
            "echo '{0}' | xxd -r -p > privkey.bin".format(client.key),
            # add wrapper
            "printf '\\x30\\x2e\\x02\\x01\\x01\\x04\\x20' > {0}".format(der_file),
            "cat privkey.bin >> {0}".format(der_file),
            "printf '\\xa0\\x07\\x06\\x05\\x2b\\x81\\x04\\x00\\x0a' >> {0}".format(der_file),
            # convert binary key to PEM
            "openssl ec -inform DER -in {0} -out {1}".format(der_file, file_name),
            "chmod 666 {0}".format(file_name),
        ]

        run = plan.run_sh(
            description="Convert ethereum private key to PEM",
            image="alpine/openssl:3.3.3",
            store=[
                StoreSpec(
                    src="{0}/{1}".format(CLIENT_KEY_DIRPATH_ON_SERVICE, file_name),
                    name="{0}-{1}-key".format(service_instance_name, client.name)),
            ],
            run=util.join_cmds(cmds),
        )

        client_key_artifacts[client.hostname] = struct(
            filename=file_name,
            artifact=run.files_artifacts[0],
        )

    return client_key_artifacts

def create_config_artifact(
    plan,
    service_instance_name,
    client_key_artifacts,
    observability_helper,
):
    config_data = {
        "Clients": client_key_artifacts,
        "KeyDir": CLIENT_KEY_DIRPATH_ON_SERVICE,
    }

    config_template_and_data = ethereum_package_shared_utils.new_template_and_data(
        read_file(CONFIG_TEMPLATE_FILEPATH), config_data
    )

    config_artifact_name = plan.render_templates(
        {
            CONFIG_FILE_NAME: config_template_and_data,
        },
        name="{0}-config".format(service_instance_name),
    )

    return config_artifact_name


def make_service_config(
    plan,
    signer_params,
    tls_artifact,
    config_artifact_name,
    client_key_artifacts,
    observability_helper,
):
    ports = dict(get_used_ports())

    cmd = []

    # apply customizations

    if observability_helper.enabled:
        observability.configure_op_service_metrics(cmd, ports)
    
    cmd += signer_params.extra_params

    return ServiceConfig(
        image="{0}:{1}".format(signer_params.image, signer_params.tag),
        ports=ports,
        cmd=cmd,
        env_vars={
            "OP_SIGNER_RPC_PORT": str(HTTP_PORT_NUM),
            "OP_SIGNER_SERVICE_CONFIG": "{0}/{1}".format(CONFIG_DIRPATH_ON_SERVICE, CONFIG_FILE_NAME)
        },
        files={
            TLS_DIR: tls_artifact,
            CONFIG_DIRPATH_ON_SERVICE: config_artifact_name,
            CLIENT_KEY_DIRPATH_ON_SERVICE: Directory(
                artifact_names=[
                    client_key_artifacts[client_hostname].artifact
                    for client_hostname in client_key_artifacts
                ]
            ),
        },
        private_ip_address_placeholder=ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )

def configure_op_signer(cmd, files, signer_service, client):
    cmd.append("--signer.endpoint=" + util.make_service_http_url(signer_service))
    cmd.append("--signer.address=" + client.address)

    files[TLS_DIR] = client.tls_artifact

def make_client(client_type, client_name):
    return struct(
        name = client_type,
        hostname = client_name,
    )


def make_populated_client(client, key, address, tls_artifact):
    return struct(
        name = client.name,
        hostname = client.hostname,
        key = key,
        address = address,
        tls_artifact = tls_artifact
    )


def generate_credentials(plan, args, store):
    gen_script = "gen-local-creds.sh"
    script_path = "/{0}".format(gen_script)

    # no way to avoid having to upload the script every time currently

    # script_artifact_name = "{0}-gen-creds".format(SERVICE_NAME)

    # script_artifact = plan.get_files_artifact(name=script_artifact_name)
    # if script_artifact == None:
    script_artifact = plan.upload_files(
        src="github.com/ethereum-optimism/infra/op-signer/{0}@edobry/op-signer-gen-creds".format(gen_script),
        # name=script_artifact_name,
    )

    cmds = [
        "chmod +x {0}".format(script_path),
        "{0} {1}".format(script_path, " ".join(args)),
    ]
    
    return plan.run_sh(
        description="Generate signer credentials",
        image="alpine/openssl:3.3.3",
        files={
            script_path: script_artifact,
        },
        env_vars={
            "OP_SIGNER_GEN_TLS_DOCKER": "false",
        },
        run=util.join_cmds(cmds),
        store=store
    ).files_artifacts


def generate_client_creds(plan, network_params, deployment_output, clients):
    client_tls_artifacts = generate_credentials(
        plan,
        ["client_tls"] + [client.hostname for client in clients],
        [
            StoreSpec(
                src="{0}/{1}".format(GENERATE_CREDS_DIR, client.hostname),
                name="{0}-creds".format(client.hostname),
            ) for client in clients
        ]
    )
    
    client_map = {}

    for client_num, client in enumerate(clients):
        private_key = util.read_service_private_key(
            plan,
            deployment_output,
            client.name,
            network_params,
        )

        address = util.read_service_network_config_value(
            plan,
            deployment_output,
            client.name,
            network_params,
            ".address",
        )

        client_map[client.name] = make_populated_client(
            client,
            private_key,
            address,
            client_tls_artifacts[client_num]
        )

    return client_map
