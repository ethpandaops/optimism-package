"""Registry for docker images used throughout the package."""

# Image IDs, just to avoid magic strings in the codebase
OP_GETH = "op-geth"
OP_RETH = "op-reth"
OP_ERIGON = "op-erigon"
OP_NETHERMIND = "op-nethermind"
OP_BESU = "op-besu"
OP_RBUILDER = "op-rbuilder"

OP_NODE = "op-node"
KONA_NODE = "kona-node"
HILDR = "hildr"

OP_BATCHER = "op-batcher"
OP_CHALLENGER = "op-challenger"
OP_SUPERVISOR = "op-supervisor"
OP_PROPOSER = "op-proposer"
OP_DEPLOYER = "op-deployer"
OP_FAUCET = "op-faucet"

PROXYD = "proxyd"

ROLLUP_BOOST = "rollup-boost"
DA_SERVER = "da-server"
TX_FUZZER = "tx-fuzzer"

DEPLOYMENT_UTILS = "deployment-utils"

PROMETHEUS = "prometheus"
GRAFANA = "grafana"
LOKI = "loki"
PROMTAIL = "promtail"


_DEFAULT_IMAGES = {
    # EL images
    OP_GETH: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
    OP_RETH: "ghcr.io/paradigmxyz/op-reth:latest",
    OP_ERIGON: "testinprod/op-erigon:latest",
    OP_NETHERMIND: "nethermind/nethermind:latest",
    OP_BESU: "ghcr.io/optimism-java/op-besu:latest",
    OP_RBUILDER: "ghcr.io/flashbots/op-rbuilder:latest",
    # CL images
    OP_NODE: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop",
    KONA_NODE: "ghcr.io/op-rs/kona/kona-node:latest",
    HILDR: "ghcr.io/optimism-java/hildr:latest",
    # Batching
    OP_BATCHER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:develop",
    # Challenger
    OP_CHALLENGER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-challenger:develop",
    # Supervisor
    OP_SUPERVISOR: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:develop",
    # Proposer
    OP_PROPOSER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:develop",
    # deployer
    OP_DEPLOYER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.0-rc.2",
    # Faucet
    # TODO: update to use a versioned image when available
    # For now, we'll need users to pass the image explicitly
    OP_FAUCET: "",
    # Proxyd
    PROXYD: "us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd:v4.14.2",
    # Sidecar
    ROLLUP_BOOST: "flashbots/rollup-boost:latest",
    # DA Server
    DA_SERVER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/da-server:latest",
    # Tx Fuzzer
    TX_FUZZER: "ethpandaops/tx-fuzz:master",
    # utils
    DEPLOYMENT_UTILS: "mslipper/deployment-utils:latest",
    # observability
    PROMETHEUS: "prom/prometheus:v3.1.0",
    GRAFANA: "grafana/grafana:11.5.0",
    LOKI: "grafana/loki:3.3.2",
    PROMTAIL: "grafana/promtail:3.3.2",
}


def Registry(images={}):
    """Registry for docker images used throughout the package.

    The user-provided images will override the default images.

    Args:
        images: dict of image IDs to Docker images.
    Returns:
        Registry object with a `get` method.
    """
    _check_images(images)
    _images = _DEFAULT_IMAGES | images

    return struct(
        get=_images.get,
        as_dict=lambda: dict(_images),
    )


def _check_images(images):
    images_type = type(images)
    if images_type != "dict":
        fail("images must be a dict, got {}".format(images_type))

    for id in images:
        image_type = type(images[id])
        if image_type != "string":
            fail("image {} must be a string, got {}".format(id, image_type))
