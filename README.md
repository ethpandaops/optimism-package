## Welcome to Optimism Package
The default package for Optimism

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
```

Please note, by default your network will be running a `minimal` preset Ethereum network. Click [here](https://github.com/ethereum/consensus-specs/blob/dev/configs/minimal.yaml) to learn more about minimal preset. You can [customize](https://github.com/ethpandaops/ethereum-package) the L1 Ethereum network by modifying the `ethereum_package` configuration.

You can also completely remove `ethereum_package` from your configuration in which case it will default to a `minimal` preset Ethereum network.

## Quickstart
#### Run with your own configuration

Kurtosis packages are parameterizable, meaning you can customize your network and its behavior to suit your needs by storing parameters in a file that you can pass in at runtime like so:

```bash
kurtosis run github.com/ethpandaops/optimism-package --args-file https://raw.githubusercontent.com/ethpandaops/optimism-package/main/network_params.yaml
```

For `--args-file` you can pass a local file path or a URL to a file.

To clean up running enclaves and data, you can run:

```bash
kurtosis clean -a
```

This will stop and remove all running enclaves and **delete all data**.

# L2 Contract deployer
The enclave will automatically deploy an optimism L2 contract on the L1 network. The contract address will be printed in the logs. You can use this contract address to interact with the L2 network.

Please refer to this Dockerfile if you want to see how the contract deployer image is built: [Dockerfile](https://github.com/ethpandaops/eth-client-docker-image-builder/blob/master/op-contract-deployer/Dockerfile)


## Configuration

To configure the package behaviour, you can modify your `network_params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults provided:

```yaml
optimism_package:
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
        # Defaults to None - not activated - decimal value
        # Offset is in seconds
        granite_time_offset: ""

        # Holocene fork
        # Defaults to None - not activated - decimal value
        # Offset is in seconds
        holocene_time_offset: ""

        # Interop fork
        # Defaults to None - not activated - decimal value
        # Offset is in seconds
        interop_time_offset: ""

        # Whether to fund dev accounts on L2
        # Defaults to True
        fund_dev_accounts: true

      # Default batcher configuration
      batcher_params:
        # The Docker image that should be used for the batcher; leave blank to use the default op-batcher image
        image: ""

        # A list of optional extra params that will be passed to the batcher container for modifying its behaviour
        extra_params: []

      # Additional services to run alongside the network
      # Defaults to []
      # Available services:
      # - blockscout
      additional_services: []

  # L2 contract deployer configuration - used for all L2 networks
  # The docker image that should be used for the L2 contract deployer
  op_contract_deployer_params:
    image: mslipper/op-deployer:latest
    artifacts_url: https://storage.googleapis.com/oplabs-contract-artifacts/artifacts-v1-4accd01f0c35c26f24d2aa71aba898dd7e5085a2ce5daadc8a84b10caf113409.tar.gz

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

  # Whether the environment should be persistent; this is WIP and is slowly being rolled out accross services
  # Defaults to false
  persistent: false
```

### Additional configuration recommendations

It is required you to launch an L1 Ethereum node to interact with the L2 network. You can use the `ethereum_package` to launch an Ethereum node. The `ethereum_package` configuration is as follows:

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
  additional_services:
    - dora
    - blockscout
```

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
  additional_services:
    - dora
    - blockscout
```
Note: if configuring multiple L2s, make sure that the `network_id` and `name` are set to differentiate networks.

### Additional configurations
Please find examples of additional configurations in the [test folder](.github/tests/).
