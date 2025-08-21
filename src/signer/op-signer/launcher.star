_ethereum_package_constants = import_module(
    "github.com/ethpandaops/ethereum-package/src/package_io/constants.star"
)

_net = import_module("/src/util/net.star")
_registry = import_module("/src/package_io/registry.star")

_SIGNER_CONFIG_DIR = "/op-signer/config"
_SIGNER_CREDENTIALS_DIR = "/op-signer/credentials"
_SIGNER_PRIVATE_KEYS_DIR = "/op-signer/private-keys"


def launch(plan, params, network_params, clients, registry):
    # First we check that the client structs (holding the hostnames of the connected services) are valid
    for client in clients:
        _assert_client(client)

    # Now we upload the scripts we are going to need
    script_artifacts = _create_script_artifacts(plan=plan, params=params)

    # Now we create the credential artifacts
    #
    # These will contain CA & TLS files for both signer and all the clients.
    #
    # They will also be used by the clients to establish secure connections.
    credentials = _create_credentials(
        plan=plan,
        params=params,
        # To get the credentials for the signer as well as the other clients, we'll append the signer to the clients map
        #
        # We only need to do this for the credentials since the signer itself does not need a private key file
        hosts=[client.hostname for client in clients] + [params.service_name],
        script_artifacts=script_artifacts,
        registry=registry,
    )

    # The next thing we need is to take the HEX private keys from the clients
    # and convert them to PEM files
    #
    # This call will give us a map of private keys (file name & artifact) keyed by the client hostname
    private_keys = _create_private_keys(
        plan=plan,
        params=params,
        clients=clients,
        script_artifacts=script_artifacts,
        registry=registry,
    )

    # Then the signer config file itself
    #
    # This config points to the private keys of the clients so we'll need to pass them along
    config = _create_signer_config(
        plan=plan,
        params=params,
        network_params=network_params,
        clients=clients,
        private_keys=private_keys,
    )

    config = get_service_config(
        plan=plan,
        params=params,
        credentials=credentials,
        private_keys=private_keys,
        config=config,
    )

    service = plan.add_service(
        name=params.service_name,
        config=config,
    )

    return struct(service=service, credentials=credentials)


def get_service_config(plan, params, credentials, private_keys, config):
    return ServiceConfig(
        image=params.image,
        labels=params.labels,
        ports=_net.ports_to_port_specs(params.ports),
        cmd=[],
        files={
            _SIGNER_CREDENTIALS_DIR: credentials.artifact,
            _SIGNER_CONFIG_DIR: config.artifact,
            _SIGNER_PRIVATE_KEYS_DIR: Directory(
                artifact_names=[
                    private_key.artifact for private_key in private_keys.values()
                ]
            ),
        },
        env_vars={
            "OP_SIGNER_TLS_CA": "{}/{}".format(
                _SIGNER_CREDENTIALS_DIR, credentials.ca.crt
            ),
            "OP_SIGNER_TLS_CERT": "{}/{}".format(
                _SIGNER_CREDENTIALS_DIR,
                credentials.hosts[params.service_name].tls.crt,
            ),
            "OP_SIGNER_TLS_KEY": "{}/{}".format(
                _SIGNER_CREDENTIALS_DIR,
                credentials.hosts[params.service_name].tls.key,
            ),
            "OP_SIGNER_RPC_PORT": str(params.ports[_net.HTTP_PORT_NAME].number),
            "OP_SIGNER_SERVICE_CONFIG": "{}/{}".format(
                _SIGNER_CONFIG_DIR, config.config
            ),
        },
        private_ip_address_placeholder=_ethereum_package_constants.PRIVATE_IP_ADDRESS_PLACEHOLDER,
    )


# This function generates the credentials to be used for communication between the signer and the clients
def _create_credentials(plan, params, hosts, script_artifacts, registry):
    generate_credentials = plan.run_sh(
        name="{}-gen-creds".format(params.service_name),
        description="Generate local credentials for op-signer",
        run="/scripts/gen-local-creds.sh all {}".format(" ".join(hosts)),
        image=registry.get(_registry.OPENSSL),
        files={"/scripts": script_artifacts},
        env_vars={
            "TLS_DIR": "/tls",
        },
        store=[
            StoreSpec(
                src="/tls",
                name="{}--creds".format(params.service_name),
            ),
        ],
    )

    return struct(
        # We'll return the credentials artifact itself
        artifact=generate_credentials.files_artifacts[0],
        # As well as the relative paths to all the files within it
        ca=struct(crt="ca.crt", key="ca.key"),
        hosts={
            hostname: struct(
                tls=struct(
                    crt="{}/tls.crt".format(hostname),
                    key="{}/tls.key".format(hostname),
                )
            )
            for hostname in hosts
        },
    )


def _create_signer_config(
    plan, params, network_params, clients, private_keys
):
    config_artifact_template = read_file("./templates/config.yaml.tmpl")
    config_file_name = "config.yaml"

    artifact = plan.render_templates(
        config={
            config_file_name: struct(
                template=config_artifact_template,
                data={
                    "Clients": [
                        struct(
                            hostname=client.hostname,
                            private_key="{}/{}".format(
                                _SIGNER_PRIVATE_KEYS_DIR,
                                private_keys[client.hostname].key,
                            ),
                            chain_id=network_params.network_id,
                        )
                        for client in clients
                    ],
                },
            ),
        },
        name="{0}--config".format(params.service_name),
    )

    return struct(
        # We'll return the config artifact itself
        artifact=artifact,
        # As well as the relative path to the config file
        config=config_file_name,
    )


# Creates a map of private keys keyed by client hostnames
def _create_private_keys(plan, params, clients, script_artifacts, registry):
    return {
        client.hostname: _create_private_key(
            plan=plan,
            params=params,
            client=client,
            script_artifacts=script_artifacts,
            registry=registry,
        )
        for client in clients
    }


# Converts a HEX private key to a PEM format
def _create_private_key(plan, params, client, script_artifacts, registry):
    key_file_name = "{}.pem".format(client.hostname)
    key_file_path = "/tmp/{}".format(key_file_name)

    convert_private_key = plan.run_sh(
        name="{}-convert-pk".format(client.hostname),
        description="Convert private key for {} to PEM format".format(client.hostname),
        run="/scripts/convert-private-key.sh {} > {}".format(
            client.private_key, key_file_path
        ),
        image=registry.get(_registry.OPENSSL),
        files={"/scripts": script_artifacts},
        store=[
            StoreSpec(
                src=key_file_path,
                name="{}--pem--{}".format(params.service_name, client.hostname),
            ),
        ],
    )

    return struct(
        # We'll return the private key artifact itself
        artifact=convert_private_key.files_artifacts[0],
        # As well as the relative file path
        key=key_file_name,
    )


# Helper function that uploads all the shell scripts we'll need for the signer launch
def _create_script_artifacts(plan, params):
    # First we upload the local shell script that generates the credentials
    return plan.upload_files(
        src="./scripts",
        name="{}--scripts".format(params.service_name),
    )


# Helper function to assert client struct validity
def _assert_client(client):
    typeof_client = type(client)
    if typeof_client != "struct":
        fail("op-signer: client must be a struct, got {}".format(typeof_client))

    if not hasattr(client, "hostname"):
        fail(
            "op-signer: client struct must have a 'hostname' field, got {}".format(
                client
            )
        )

    typeof_hostname = type(client.hostname)
    if typeof_hostname != "string":
        fail(
            "op-signer: client struct 'hostname' field must be a string, got {}".format(
                typeof_hostname
            )
        )

    if not hasattr(client, "private_key"):
        fail(
            "op-signer: client struct must have a 'private_key' field, got {}".format(
                client
            )
        )

    typeof_private_key = type(client.private_key)
    if typeof_private_key != "string":
        fail(
            "op-signer: client struct 'private_key' field must be a string, got {}".format(
                typeof_private_key
            )
        )
