"""
Support for the op-faucet service.

TODO: op-faucet doesn't have a proper release yet. Don't use this for now
unless you know what you're doing.
"""


def launch(
    plan,
    service_name,
    image,
    faucets,
):
    """Launch the op-faucet service.

    Args:
        plan: The plan to add the service to.
        service_name (str): The name of the service.
        image (str): The image to use for the op-faucet service.
        faucets (list of faucet_data): The faucets to use for the op-faucet service.
    """
    faucet_config = plan.render_templates(
        name="faucet_config",
        description="rendering op-faucet config",
        config={
            "/config.yaml": struct(
                template=read_file("./config.tmpl"),
                data=faucets,
            )
        },
    )

    config = _get_config(
        image=image,
        faucet_config=faucet_config,
        network_ids=[f.ChainID for f in faucets],
    )
    plan.add_service(service_name, config)


def _get_config(
    image,
    faucet_config,
    network_ids,
):
    """Get the ServiceConfig for the op-faucet service.

    Args:
        image (str): The image to use for the op-faucet service.
        faucet_config (artifact): The config artifact for the op-faucet service.
        network_ids (list of str): The network IDs to use for the op-faucet service.
    """
    mount_path = "/config"
    cmd = [
        "op-faucet",
        "--rpc.port=9000",
        "--config={0}/config.yaml".format(mount_path),
    ]

    return ServiceConfig(
        image=image,
        cmd=cmd,
        ports={
            "rpc": PortSpec(
                number=9000,
                transport_protocol="TCP",
                application_protocol="http",
            ),
        },
        labels={
            "op.kind": "faucet",
            "op.network.id": "-".join([str(network_id) for network_id in network_ids]),
        },
        files={
            mount_path: faucet_config,
        },
    )


def faucet_data(
    chain_id,
    el_rpc,
    private_key,
    name=None,
):
    """Constructor for a faucet data struct.

    Args:
        chain_id (str): The chain ID the faucet will be used on.
        el_rpc (str): The EL RPC the faucet will use.
        private_key (str): The private key of the underlying faucet wallet.
        name (str): The name of the faucet.
    """
    if name == None:
        name = chain_id

    return struct(
        # capitalization for Go template expansion
        Name=name,
        ChainID=chain_id,
        RPC=el_rpc,
        PrivateKey=private_key,
    )
