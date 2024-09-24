## Welcome to Optimism Package
The default package for Optimism
```yaml
optimism_package:
  participants:
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
  # Specification of the optimism-participants in the network
  participants:
    # EL(Execution Layer) Specific flags
      # The type of EL client that should be started
      # Valid values are:
      # op-geth
      # op-reth
      # op-erigon
      # op-nethermind
      # op-besu
    - el_type: geth

      # The Docker image that should be used for the EL client; leave blank to use the default for the client type
      # Defaults by client:
      # - op-geth: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest
      # - op-reth: parithoshj/op-reth:latest
      # - op-erigon: testinprod/op-erigon:latest
      # - op-nethermind: nethermindeth/nethermind:op-c482d56
      # - op-besu: ghcr.io/optimism-java/op-besu:latest
      el_image: ""

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


  # Additional services to run alongside the network
  # Defaults to []
  # Available services:
  # - blockscout
  # - da_server
  additional_services: []

  # Configuration place for da-server - https://github.com/ethereum-optimism/optimism/tree/develop/op-alt-da
  da_server_params:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/da-server:dev
    build_image: true
    # A list of optional extra params that will be passed to the da-server container for modifying its behaviour
    da_server_extra_args: []
    generic_commitment: false

  # L2 contract deployer configuration
  # The docker image that should be used for the L2 contract deployer
  op_contract_deployer_params:
    image: ethpandaops/optimism-contract-deployer:develop
```

### Additional configuration recommendations

It is required you to launch an L1 Ethereum node to interact with the L2 network. You can use the `ethereum_package` to launch an Ethereum node. The `ethereum_package` configuration is as follows:

```yaml
optimism_package:
  participants:
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
