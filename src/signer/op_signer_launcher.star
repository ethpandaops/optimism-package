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

def make_client(client_type, client_name, client_key):
    return struct(
        name = client_type,
        hostname = client_name,
        key = client_key,
    )

def launch(
    plan,
    signer_params,
    network_params,
    clients,
    observability_helper,
):
    service_instance_name = util.make_service_instance_name(SERVICE_NAME, network_params)

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
        config_artifact_name,
        client_key_artifacts,
        observability_helper,
    ))

    observability.register_op_service_metrics_job(
        observability_helper, service, network_params.network
    )

    return service

def create_key_artifacts(
    plan,
    service_instance_name,
    clients,
):
    client_key_artifacts = {}

    for client in clients:
        file_name = "{0}_key.pem".format(client.name)
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
            "OP_SIGNER_TLS_ENABLED": "false",
            "OP_SIGNER_SERVICE_CONFIG": "{0}/{1}".format(CONFIG_DIRPATH_ON_SERVICE, CONFIG_FILE_NAME)
        },
        files={
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

def configure_op_signer(cmd, signer_service, client_address):
    cmd.append("--signer.tls.enabled=false")
    cmd.append("--signer.endpoint=" + util.make_service_http_url(signer_service))
    cmd.append("--signer.address=" + client_address)
