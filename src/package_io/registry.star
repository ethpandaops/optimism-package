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

OP_SUPERVISOR = "op-supervisor"
KONA_SUPERVISOR = "kona-supervisor"

OP_BATCHER = "op-batcher"
OP_CHALLENGER = "op-challenger"
OP_PROPOSER = "op-proposer"
OP_CONDUCTOR = "op-conductor"
OP_DEPLOYER = "op-deployer"
OP_FAUCET = "op-faucet"
OP_CONDUCTOR_OPS = "op-conductor-ops"
OP_INTEROP_MON = "op-interop-mon"

PROXYD = "proxyd"

ROLLUP_BOOST = "rollup-boost"
DA_SERVER = "da-server"
TX_FUZZER = "tx-fuzzer"

DEPLOYMENT_UTILS = "deployment-utils"

PROMETHEUS = "prometheus"
GRAFANA = "grafana"
LOKI = "loki"
PROMTAIL = "promtail"

OP_BLOCKSCOUT = "op-blockscout"
OP_BLOCKSCOUT_VERIFIER = "op-blockscout-verifier"


_DEFAULT_IMAGES = {
    # EL images
    OP_GETH: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest",
    OP_RETH: "ghcr.io/paradigmxyz/op-reth:latest",
    OP_ERIGON: "testinprod/op-erigon:latest",
    OP_NETHERMIND: "nethermind/nethermind:latest",
    OP_BESU: "ghcr.io/optimism-java/op-besu:latest",
    OP_RBUILDER: "ghcr.io/flashbots/op-rbuilder:latest",
    # CL images
    OP_NODE: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:v1.13.4",
    KONA_NODE: "ghcr.io/op-rs/kona/kona-node:latest",
    HILDR: "ghcr.io/optimism-java/hildr:latest",
    # Batching
    OP_BATCHER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:v1.14.0",
    # Challenger
    OP_CHALLENGER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-challenger:v1.5.1",
    # op-supervisor
    OP_SUPERVISOR: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:v0.3.0-dev.4",
    # kona-supervisor
    KONA_SUPERVISOR: "ghcr.io/op-rs/kona/kona-supervisor:latest",
    # Proposer
    OP_PROPOSER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:v1.10.0",
    # Conductor
    OP_CONDUCTOR: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-conductor:v0.7.1",
    # deployer
    OP_DEPLOYER: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.0-rc.2",
    # Faucet
    OP_FAUCET: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-faucet:develop",
    # conductor-ops
    OP_CONDUCTOR_OPS: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-conductor-ops:v0.0.2",
    # Interop Monitor
    OP_INTEROP_MON: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-interop-mon:latest",
    # Proxyd
    PROXYD: "us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd:v4.14.5",
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
    # Explorers
    OP_BLOCKSCOUT: "blockscout/blockscout-optimism:6.8.0",
    OP_BLOCKSCOUT_VERIFIER: "ghcr.io/blockscout/smart-contract-verifier:v1.9.0",
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
