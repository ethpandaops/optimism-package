## Welcome to Optimism Package
default package for Optimism
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
