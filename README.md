# Welcome to Optimism Package

The default package for Optimism. The kurtosis package uses [op-deployer](https://github.com/ethereum-optimism/optimism/tree/develop/op-deployer) to manage
the L2 chains and all associated artifacts such as contract deployments.

```yaml
optimism_package:
  chains:
    - participants:
        - el_type: op-geth
          cl_type: op-node
        - el_type: op-reth
        - el_type: op-erigon
        - el_type: op-nethermind
ethereum_package:
  network_params:
    preset: minimal
    genesis_delay: 5
    additional_preloaded_contracts: '
      {
        "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
          "balance": "0ETH",
          "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
          "storage": {},
          "nonce": "1"
        }
      }
    '

```

Please note, by default your network will be running a `minimal` preset Ethereum network. Click [here](https://github.com/ethereum/consensus-specs/blob/dev/configs/minimal.yaml) to learn more about minimal preset. You can [customize](https://github.com/ethpandaops/ethereum-package) the L1 Ethereum network by modifying the `ethereum_package` configuration.

You can also completely remove `ethereum_package` from your configuration in which case it will default to a `minimal` preset Ethereum network.

## Quickstart

### Run with your own configuration

Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:

```shell
kurtosis run github.com/ethpandaops/optimism-package --args-file https://raw.githubusercontent.com/ethpandaops/optimism-package/main/network_params.yaml
```

For `--args-file` parameters file, you can pass a local file path or a URL to a file.

To clean up running enclaves and data, you can run:

```shell
kurtosis clean -a
```

This will stop and remove all running enclaves and **delete all data**.

### Run with changes to the optimism package

If you are attempting to test any changes to the package code, you can point to the directory as the `run` argument

```shell
cd ~/go/src/github.com/ethpandaops/optimism-package
kurtosis run . --args-file ./network_params.yaml
```

## L2 Contract deployer

The enclave will automatically deploy an optimism L2 contract on the L1 network. The contract address will be printed in the logs. You can use this contract address to interact with the L2 network.

Please refer to this Dockerfile if you want to see how the contract deployer image is built: [Dockerfile](https://github.com/ethereum-optimism/optimism/blob/develop/op-deployer/Dockerfile.default)

## Configuration

To configure the package behaviour, you can modify your `network_params.yaml` file and use that as the input to `--args-file`.
The full YAML schema that can be passed in is as follows with the defaults provided:

```yaml
optimism_package:
  # Observability configuration
  observability:
    # Whether to provision an observability stack (prometheus, loki, promtail, grafana)
    enabled: true
    # Whether to enable features exclusive to the K8s backend (ie log collection)
    enable_k8s_features: false
    # Default prometheus configuration
    prometheus_params:
      storage_tsdb_retention_time: "1d"
      storage_tsdb_retention_size: "512MB"
      # Resource management for prometheus container
      # CPU is milicores
      # RAM is in MB
      min_cpu: 10
      max_cpu: 1000
      min_mem: 128
      max_mem: 2048
      # Prometheus docker image to use
      image: "prom/prometheus:v3.1.0"
    # Default loki configuration
    loki_params:
      # Loki docker image to use
      image: "grafana/loki:3.3.2"
      # Resource management for loki container
      # CPU is milicores
      # RAM is in MB
      min_cpu: 10
      max_cpu: 1000
      min_mem: 128
      max_mem: 2048
    # Default promtail configuration
    promtail_params:
      # Promtail docker image to use
      image: "grafana/promtail:3.3.2"
      # Resource management for promtail container
      # CPU is milicores
      # RAM is in MB
      min_cpu: 10
      max_cpu: 1000
      min_mem: 128
      max_mem: 2048
    # Default grafana configuration
    grafana_params:
      # A list of locators for grafana dashboards to be loaded be the grafana service
      dashboard_sources:
        # Default public Optimism dashboards
        - github.com/ethereum-optimism/grafana-dashboards-public/resources
      # Resource management for grafana container
      # CPU is milicores
      # RAM is in MB
      min_cpu: 10
      max_cpu: 1000
      min_mem: 128
      max_mem: 2048
      # Grafana docker image to use
      image: "grafana/grafana:11.5.0"
  # Superchain configuration
  superchains:
    # Superchains are uniquely identified by their name
    superchain-a:
      # Superchain can be toggled by the enabled attribute
      enabled: true

      # List of L2 network_ids that participate in this set
      # 
      # Please refer to chains[].network_params.network_id for more information
      participants: ["2151908"]

      # OR a special "*" meaning all networks
      participants: "*"   
    # If superchain config is left empty, a superchain with all L2 networks will be created
    superchain-other:
  # Supervisor configuration
  supervisors:
    # Supervisors are uniquely identified by their name
    supervisor-a:
      # Supervisor can be toggled by the enabled attribute
      enabled: true

      # Supervisor needs to specify which superchain it is a part of
      superchain: superchain-a

      # The Docker image that should be used for the supervisor; leave blank to use the default op-supervisor image
      image: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-supervisor:develop"

      # Optional list of CLI arguments that will be passed to the op-supervisor command for modifying its behaviour
      extra_params: []

  # AltDA Deploy Configuration, which is passed to op-deployer.
  #
  # For simplicity we currently enforce chains to all be altda or all rollups.
  # Adding a single altda chain to a cluster essentially makes all chains have altda levels of security.
  #
  # To setup an altda cluster, make sure to
  # 1. Set altda_deploy_config.use_altda to true (and da_commitment_type to KeccakCommitment, see TODO below)
  # 2. For each chain,
  #    - Add "da_server" to the additional_services list if it should use alt-da
  #    - For altda chains, set da_server_params to use an image and cmd of your choice (one could use da-server, another eigenda-proxy, another celestia proxy, etc). If unset, op's default da-server image will be used.
  altda_deploy_config:
    use_altda: false
    # TODO: Is this field redundant? Afaiu setting it to GenericCommitment will not deploy the
    # DAChallengeContract, and hence is equivalent to setting use_altda to false.
    # Furthermore, altda rollups using generic commitments might anyways need to support failing over
    # to keccak commitments if the altda layer is down.
    da_commitment_type: KeccakCommitment
    da_challenge_window: 100
    da_resolve_window: 100
    da_bond_size: 0
    da_resolver_refund_percentage: 0

  # An array of L2 networks to run
  chains:
    # Specification of the optimism-participants in the network
    - participants:
      # EL(Execution Layer) Specific flags
        # The type of EL client that should be started
        # Valid values are:
        # op-geth
        # op-reth
        # op-erigon
        # op-nethermind
        # op-besu
      - el_type: op-geth

        # The Docker image that should be used for the EL client; leave blank to use the default for the client type
        # Defaults by client:
        # - op-geth: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest
        # - op-reth: parithoshj/op-reth:latest
        # - op-erigon: testinprod/op-erigon:latest
        # - op-nethermind: nethermindeth/nethermind:op-c482d56
        # - op-besu: ghcr.io/optimism-java/op-besu:latest
        el_image: ""

        # The log level string that this participant's EL client should log at
        # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
        # global `logLevel` = `info` then Geth would receive `3`, Besu would receive `INFO`, etc.)
        # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
        # over a specific participant's logging
        el_log_level: ""

        # A list of optional extra env_vars the el container should spin up with
        el_extra_env_vars: {}

        # A list of optional extra labels the el container should spin up with
        # Example; el_extra_labels: {"ethereum-package.partition": "1"}
        el_extra_labels: {}

        # A list of optional extra params that will be passed to the EL client container for modifying its behaviour
        el_extra_params: []

        # A list of tolerations that will be passed to the EL client container
        # Only works with Kubernetes
        # Example: el_tolerations:
        # - key: "key"
        #   operator: "Equal"
        #   value: "value"
        #   effect: "NoSchedule"
        #   toleration_seconds: 3600
        # Defaults to empty
        el_tolerations: []

        # Persistent storage size for the EL client container (in MB)
        # Defaults to 0, which means that the default size for the client will be used
        # Default values can be found in /src/package_io/constants.star VOLUME_SIZE
        el_volume_size: 0

        # Resource management for el containers
        # CPU is milicores
        # RAM is in MB
        # Defaults to 0, which results in no resource limits
        el_min_cpu: 0
        el_max_cpu: 0
        el_min_mem: 0
        el_max_mem: 0

      # CL(Consensus Layer) Specific flags
        # The type of CL client that should be started
        # Valid values are:
        # op-node
        # hildr
        cl_type: op-node

        # The Docker image that should be used for the CL client; leave blank to use the default for the client type
        # Defaults by client:
        # - op-node: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop
        # - hildr: ghcr.io/optimism-java/hildr:latest
        cl_image: ""

        # The log level string that this participant's CL client should log at
        # If this is emptystring then the global `logLevel` parameter's value will be translated into a string appropriate for the client (e.g. if
        # If this is not emptystring, then this value will override the global `logLevel` setting to allow for fine-grained control
        # over a specific participant's logging
        cl_log_level: ""

        # A list of optional extra env_vars the cl container should spin up with
        cl_extra_env_vars: {}

        # A list of optional extra labels that will be passed to the CL client Beacon container.
        # Example; cl_extra_labels: {"ethereum-package.partition": "1"}
        cl_extra_labels: {}

        # A list of optional extra params that will be passed to the CL client Beacon container for modifying its behaviour
        # If the client combines the Beacon & validator nodes (e.g. Teku, Nimbus), then this list will be passed to the combined Beacon-validator node
        cl_extra_params: []

        # A list of tolerations that will be passed to the CL client container
        # Only works with Kubernetes
        # Example: el_tolerations:
        # - key: "key"
        #   operator: "Equal"
        #   value: "value"
        #   effect: "NoSchedule"
        #   toleration_seconds: 3600
        # Defaults to empty
        cl_tolerations: []

        # Persistent storage size for the CL client container (in MB)
        # Defaults to 0, which means that the default size for the client will be used
        # Default values can be found in /src/package_io/constants.star VOLUME_SIZE
        cl_volume_size: 0

        # Resource management for cl containers
        # CPU is milicores
        # RAM is in MB
        # Defaults to 0, which results in no resource limits
        cl_min_cpu: 0
        cl_max_cpu: 0
        cl_min_mem: 0
        cl_max_mem: 0

      # Builder client specific flags
        # The type of builder EL client that should be started
        # Valid values are:
        # op-geth
        # op-reth
        # op-rbuilder
        el_builder_type: ""

        # The Docker image that should be used for the builder EL client; leave blank to use the default for the client type
        # Defaults by client:
        # - op-geth: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest
        # - op-reth: parithoshj/op-reth:latest
        # - op-rbuilder: ghcr.io/flashbots/op-rbuilder:latest
        el_builder_image: ""

        # Builder secret key used by op-rbuilder to sign transactions
        # Defaults to None - not used
        el_builder_key: ""
        
        # The type of builder CL client that should be started
        # Valid values are:
        # op-node
        # hildr
        cl_builder_type: ""

        # The Docker image that should be used for the builder CL client; leave blank to use the default for the client type
        # Defaults by client:
        # - op-node: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:develop
        # - hildr: ghcr.io/optimism-java/hildr:latest
        cl_builder_image: ""

        # Participant specific flags
        # Node selector
        # Only works with Kubernetes
        # Example: node_selectors: { "disktype": "ssd" }
        # Defaults to empty
        node_selectors: {}

        # A list of tolerations that will be passed to the EL/CL/validator containers
        # This is to be used when you don't want to specify the tolerations for each container separately
        # Only works with Kubernetes
        # Example: tolerations:
        # - key: "key"
        #   operator: "Equal"
        #   value: "value"
        #   effect: "NoSchedule"
        #   toleration_seconds: 3600
        # Defaults to empty
        tolerations: []

        # Count of nodes to spin up for this participant
        # Default to 1
        count: 1

      # Default configuration parameters for the network
      network_params:
        # Network name, used to enable syncing of alternative networks
        # Defaults to "kurtosis"
        network: "kurtosis"

        # The network ID of the network.
        # Must be unique for each network (if you run multiple networks)
        # Defaults to "2151908"
        network_id: "2151908"

        # Seconds per slots
        seconds_per_slot: 2

        # Name of your rollup.
        # Must be unique for each rollup (if you run multiple rollups)
        # Defaults to "op-kurtosis"
        name: "op-kurtosis"

        # Triggering future forks in the network
        # Fjord fork
        # Defaults to 0 (genesis activation) - decimal value
        # Offset is in seconds
        fjord_time_offset: 0

        # Granite fork
        # Defaults to 0 (genesis activation) - decimal value
        # Offset is in seconds
        granite_time_offset: 0

        # Holocene fork
        # Defaults to None - not activated - decimal value
        # Offset is in seconds
        holocene_time_offset: ""

        # Isthmus fork
        # Defaults to None - not activated - decimal value
        # Offset is in seconds
        isthmus_time_offset: ""

        # Interop fork
        # Defaults to None - not activated - decimal value
        # Offset is in seconds
        interop_time_offset: ""

        # Whether to fund dev accounts on L2
        # Defaults to True
        fund_dev_accounts: true

      # Default proxyd configuration
      proxyd_params:
        # The Docker image that should be used for proxyd; leave blank to use the default image
        image: "us-docker.pkg.dev/oplabs-tools-artifacts/images/proxyd"

        # The Docker tag that should be used for proxyd; leave blank to use the default tag
        tag: ""

        # A list of optional extra params that will be passed to the proxyd container
        extra_params: []

      # Default batcher configuration
      batcher_params:
        # The Docker image that should be used for the batcher; leave blank to use the default op-batcher image
        image: ""

        # A list of optional extra params that will be passed to the batcher container for modifying its behaviour
        extra_params: []

      # Default proposer configuration
      proposer_params:
        # The Docker image that should be used for the proposer; leave blank to use the default op-proposer image
        image: ""

        # A list of optional extra params that will be passed to the proposer container for modifying its behaviour
        extra_params: []

        # Dispute game type to create via the configured DisputeGameFactory
        game_type: 1

        # Interval between submitting L2 output proposals
        proposal_internal: 10m

      # Default MEV configuration
      mev_params:
        # The Docker image that should be used for rollup boost; leave blank to use the default rollup-boost image
        # Defaults to "flashbots/rollup-boost:latest"
        rollup_boost_image: ""

        # The host of an external builder
        builder_host: ""

        # The port of an external builder
        builder_port: ""

      # Additional services to run alongside the network
      # Defaults to []
      # Available services:
      # - blockscout
      # - rollup-boost
      # - da_server
      additional_services: []

      # Configuration for da-server - https://specs.optimism.io/experimental/alt-da.html#da-server
      # TODO: each op-node and op-batcher should potentially have their own da-server, instead of sharing one like we currently do. For eg batcher needs to write via its da-server, whereas op-nodes don't.
      da_server_params:
        image: us-docker.pkg.dev/oplabs-tools-artifacts/images/da-server:latest
        # Command to pass to the container.
        # This is kept maximally generic to allow for any possible configuration, given that different
        # da layer da-servers might have completely different flags.
        # The below arguments are also the default, so can be omitted, and will work as long as the image
        # is the da-server above (which is also the default, so can also be omitted).
        cmd:
          - "da-server"
          - "--file.path=/home"
          - "--addr=0.0.0.0"
          - "--port=3100"
          - "--log.level=debug"

  challengers:
    my-challenger:
      # Whether this challenger is active
      enabled: true

      # The Docker image that should be used for the challenger; leave blank to use the default op-challenger image
      image: ""

      # List of L2 chains that this challenger is connected to
      # 
      # This field accepts several configuration types:
      # 
      # A list of network IDs, in which case the challenger will connect to all the nodes in these network
      participants: ["2151908"]

      # OR "*" meaning the challenger will connect to all nodes of all L2 networks
      participants: "*"

      # A list of optional extra params that will be passed to the challenger container for modifying its behaviour
      extra_params: []

      # Path to folder containing cannon prestate-proof.json file
      cannon_prestates_path: "static_files/prestates"

      # OR Base URL to absolute prestates to use when generating trace data.
      cannon_prestates_url: ""

      # Directory in which the challenger will store its data
      datadir: "/data/op-challenger/op-challenger-data"

  # L2 contract deployer configuration - used for all L2 networks.
  # The docker image that should be used for the L2 contract deployer.
  # Locators can be http(s) URLs, or point to an enclave artifact with
  # a pseudo URL artifact://NAME
  op_contract_deployer_params:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.0.11
    l1_artifacts_locator: https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-c193a1863182092bc6cb723e523e8313a0f4b6e9c9636513927f1db74c047c15.tar.gz
    l2_artifacts_locator: https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-c193a1863182092bc6cb723e523e8313a0f4b6e9c9636513927f1db74c047c15.tar.gz

  # The global log level that all clients should log at
  # Valid values are "error", "warn", "info", "debug", and "trace"
  # This value will be overridden by participant-specific values
  global_log_level: "info"

  # Global node selector that will be passed to all containers (unless overridden by a more specific node selector)
  # Only works with Kubernetes
  # Example: global_node_selectors: { "disktype": "ssd" }
  # Defaults to empty
  global_node_selectors: {}

  # Global tolerations that will be passed to all containers (unless overridden by a more specific toleration)
  # Only works with Kubernetes
  # Example: tolerations:
  # - key: "key"
  #   operator: "Equal"
  #   value: "value"
  #   effect: "NoSchedule"
  #   toleration_seconds: 3600
  # Defaults to empty
  global_tolerations: []

  # Whether the environment should be persistent; this is WIP and is slowly being rolled out across services
  # Defaults to false
  persistent: false

# Ethereum package configuration
ethereum_package:
  network_params:
    # The Ethereum network preset to use
    preset: minimal
    # The delay in seconds before the genesis block is mined
    genesis_delay: 5
    # Preloaded contracts for the Ethereum network
    additional_preloaded_contracts: '
      {
        "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
          "balance": "0ETH",
          "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
          "storage": {},
          "nonce": "1"
        }
      }
    '

```

### Additional configuration recommendations

#### L1 customization

It is required for you to launch an L1 Ethereum node to interact with the L2 network. You can use the `ethereum_package` to launch an Ethereum node. The `ethereum_package` configuration is as follows:

```yaml
optimism_package:
  chains:
    - participants:
        - el_type: op-geth
          cl_type: op-node
      additional_services:
        - blockscout
ethereum_package:
  participants:
    - el_type: geth
    - el_type: reth
  network_params:
    preset: minimal
    genesis_delay: 5
    additional_preloaded_contracts: '
      {
        "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
          "balance": "0ETH",
          "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
          "storage": {},
          "nonce": "1"
        }
      }
    '
  additional_services:
    - dora
    - blockscout
```

#### L2 customization with Hard Fork transitions

To spin up an L2 chain with specific hard fork transition blocks and any local docker image to run the EL/CL components,
use the `network_params` section of your arguments file to specify the hard fork transitions and custom images.

```yaml
optimism_package:
  chains:
    - participants:
      - el_type: op-geth
        el_image: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:<tag>"
        cl_type: op-node
        cl_image: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:<tag>"
      - el_type: op-geth
        el_image: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:<tag>"
        cl_type: op-node
        cl_image: "us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:<tag>"
      network_params:
        fjord_time_offset: 0
        granite_time_offset: 0
        holocene_time_offset: 4
        isthmus_time_offset: 8
```

#### Multiple L2 chains

Additionally, you can spin up multiple L2 networks by providing a list of L2 configuration parameters like so:

```yaml
optimism_package:
  chains:
    - participants:
        - el_type: op-geth
      network_params:
        name: op-rollup-one
        network_id: "3151909"
      additional_services:
        - blockscout
    - participants:
        - el_type: op-geth
      network_params:
        name: op-rollup-two
        network_id: "3151910"
      additional_services:
        - blockscout
ethereum_package:
  participants:
    - el_type: geth
    - el_type: reth
  network_params:
    preset: minimal
    genesis_delay: 5
    additional_preloaded_contracts: '
      {
        "0x4e59b44847b379578588920cA78FbF26c0B4956C": {
          "balance": "0ETH",
          "code": "0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3",
          "storage": {},
          "nonce": "1"
        }
      }
    '
  additional_services:
    - dora
    - blockscout
```

Note: if configuring multiple L2s, make sure that the `network_id` and `name` are set to differentiate networks.

#### Rollup Boost for External Block Building

Rollup Boost is a sidecar to the sequencer op-node that allows blocks to be built by an external builder on the L2 network.

To use rollup boost, you can add `rollup-boost` as an additional service and configure the `mev_params` section of your arguments file to specify the rollup boost image. Optionally, you can specify the host and port of an external builder outside of the Kurtosis enclave.

```yaml
optimism_package:
  chains:
    - participants:
        - el_builder_type: op-rbuilder
          cl_builder_type: op-node
      mev_params:
        rollup_boost_image: "flashbots/rollup-boost:latest"
        builder_host: "localhost"
        builder_port: "8545"
      additional_services:
        - rollup-boost
```

#### Run tx-fuzz to send l2 transactions

Compile [tx-fuzz](https://github.com/MariusVanDerWijden/tx-fuzz) locally per instructions in the repo. Run tx-fuzz against the l2 EL client's RPC URL and using the pre-funded wallet:

```shell
./livefuzzer spam  --sk "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" --rpc http://127.0.0.1:<port> --slot-time 2
```

#### Run contender to send l2 transactions

Install the latest [contender](https://github.com/flashbots/contender) version via cargo:
```bash
cargo install --git https://github.com/flashbots/contender --bin contender --force
```

Browse the available [scenarios](https://github.com/flashbots/contender/tree/main/scenarios) and pick one that fits your needs. For example, to download the `stress` scenario:
```bash
wget https://raw.githubusercontent.com/flashbots/contender/refs/heads/main/scenarios/stress.toml -O scenario.toml
```

In the snippet below, we use Docker to inspect the container named `op-el-1` and dynamically extract the port. You can replace this approach with a specific L2 RPC port if you prefer::
```bash
L2_PORT=$(docker inspect --format='{{(index .NetworkSettings.Ports "8545/tcp" 0).HostPort}}' $(docker ps --filter "name=op-el-1" -q)) &&
contender setup -p 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 scenario.toml http://localhost:$L2_PORT
```

Once setup is complete, you can start spamming transactions. In this example, we send 5 transactions per second for 10,000 seconds:
```bash
contender spam \
  -p 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --txs-per-second 5 \
  -d 10000 \
  scenario.toml \
  http://localhost:$L2_PORT
```
Note: For more complex scenarios like [spamBundles](https://github.com/flashbots/contender/blob/main/scenarios/spamBundles.toml), you'll need to provide L2 builder URL that supports the `eth_sendBundle` method.

### Additional configurations

Please find examples of additional configurations in the [test folder](.github/tests/).

### Useful Kurtosis commands

#### Inspect enclave -- Container/Port information

- List information about running containers and open ports

```shell
kurtosis enclave ls
kurtosis enclave inspect <enclave-name>
```

- Inspect chain state.

```shell
kurtosis files inspect <enclave-name> op-deployer-configs
```

- Dump all files generated by kurtosis to disk (for inspecting chain state/deploy configs/contract addresses etc.). A file that contains an exhaustive
  set of information about the current deployment is `files/op-deployer-configs/state.json`. Deployed contract address, roles etc can all be found here.

```shell
# dumps all files to a enclave-name prefixed directory under the current directory
kurtosis enclave dump <enclave-name>
kurtosis files download <enclave-name> op-deployer-configs <where-to-download>
```

- Get logs for running services

```shell
kurtosis service logs <enclave-name> <service-name> -f . # -f tails the log
```

- Stop/Start running service (restart sequencer/batcher/op-geth etc.)

```shell
kurtosis service stop <enclave-name> <service-name>
kurtosis service start <enclave-name> <service-name>
```

## Observability

This package optionally provisions an in-enclave observability stack consisting of Grafana, prometheus, promtail, and loki, which collects logs and metrics from the enclave.

This feature is enabled by default, but can be disabled like so:

```yaml
optimism_package:
  observability:
    enabled: false
```

You can provide custom dashboard sources to have Grafana pre-populated with your preferred dashboards. Each source should be a URL to a Github repository directory containing at minimum a `dashboards` directory:

```yaml
optimism_package:
  observability:
    grafana_params:
      dashboard_sources:
        - github.com/<org>/<repo>/<path-to-resources>
```

See [grafana-dashboards-public](https://github.com/ethereum-optimism/grafana-dashboards-public) for more info.

To access the Grafana UI, you can use the following command after starting the enclave:

```shell
just open-grafana <enclave name>
```

### Logs

Note that due to `kurtosis` limitations, log collection is not enabled by default, and is only supported for the Kubernetes backend. To enable log collection, you must set the following parameter:

```yaml
optimism_package:
  observability:
    enable_k8s_features: true
```

Note that since `kurtosis` runs pods using the namespace's default `ServiceAccount`, which is not typically able to modify cluster-level resources, such as `ClusterRoles`, as the `promtail` Helm chart requires, you must also install the `ns-authz` Helm chart to the Kubernetes cluster serving as the `kurtosis` backend using the following command:

```shell
just install-ns-authz
```

## Development

### Development environment

We use [`mise`](https://mise.jdx.dev/) as a dependency manager for these tools.
Once properly installed, `mise` will provide the correct versions for each tool. `mise` does not
replace any other installations of these binaries and will only serve these binaries when you are
working inside of the `optimism-package` directory.

#### Install `mise`

Install `mise` by following the instructions provided on the
[Getting Started page](https://mise.jdx.dev/getting-started.html#_1-install-mise-cli).

#### Install dependencies

```sh
mise install
```

## Contributing

If you have made changes and would like to submit a PR, test locally and make sure to run `lint` on your changes

```shell
kurtosis lint --format .
```

### Testing

#### Unit tests

We are using [`kurtosis-test`](https://github.com/ethereum-optimism/kurtosis-test) to run a set of unit tests against the starlark code:

```shell
# To run all unit tests
kurtosis-test .
```

The tests can be found in `*_test.star` scripts located in the `test` directory.

### Dev accounts being used

Index| Address | Private Key | In use | Tool
---|---|---|---|---
0| `0xf39F...2266` | `0xac09...f80` | ✅ | [op-transaction-fuzzer](src/transaction_fuzzer/transaction_fuzzer.star#L33)
1| `0x7099...79C8` | `0x59c6...690d` | ❌ | ""
2| `0x3C49...3359` | `0x5de4...365a` | ❌ | ""
3| `0x90F7...9b906` | `0x7c85...a07a6` | ❌ | ""
4| `0x15d3...9f1b9` | `0x47e1...9c6` | ❌ | ""
5| `0x9965...0A4dc` | `0x8b3a...ba` | ❌ | ""
6| `0x976E...9b906` | `0x92db...64e` | ❌ | ""
7| `0x14dC...3356` | `0x4bbbf...356` | ❌ | ""
8| `0x2361...226a` | `0xdbda...b97` | ❌ | ""
9| `0xa0Ee...720` | `0xa0Ee...c6` | ❌ | ""

mnemonic: `test test test test test test test test test test test junk`

