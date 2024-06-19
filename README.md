## Welcome to Optimism Package
The default package for Optimism
```yaml
optimism_package:
  participants:
    - el_type: op-geth
      cl_type: op-node
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

## Configuration

To configure the package behaviour, you can modify your `network_params.yaml` file. The full YAML schema that can be passed in is as follows with the defaults provided:

```yaml
optimism_package:
  # Specification of the optimism-participants in the network
  participants:
    # EL(Execution Layer) Specific flags
      # The type of EL client that should be started
      # Valid values are op-geth, op-reth
    - el_type: geth

      # The Docker image that should be used for the EL client; leave blank to use the default for the client type
      # Defaults by client:
      # - op-geth: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:latest
      # - op-reth: parithoshj/op-reth:latest
      # - op-erigon: testinprod/op-erigon:latest
      el_image: ""

    # CL(Consensus Layer) Specific flags
      # The type of CL client that should be started
      # Valid values are op-node, ?
      cl_type: op-node

      # The Docker image that should be used for the CL client; leave blank to use the default for the client type
      # Defaults by client:
      # - op-node: parithoshj/op-node:v1
      cl_image: ""

      # Count of nodes to spin up for this participant
      # Default to 1
      count: 1

  # Default configuration parameters for the network
  network_params:
    # Network name, used to enable syncing of alternative networks
    # Defaults to "kurtosis"
    # You can sync any public network by setting this to the network name (e.g. "mainnet", "sepolia", "holesky")
    # You can sync any devnet by setting this to the network name (e.g. "dencun-devnet-12", "verkle-gen-devnet-2")
    network: "kurtosis"

    # The network ID of the network.
    network_id: "2151908"

    # Seconds per slots
    seconds_per_slot: 2

  # Additional services to run alongside the network
  # Defaults to []
  # Available services:
  # - blockscout
  additional_services: []
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
