# FORK

## Upstream
- Repository: https://github.com/ethpandaops/optimism-package
- Base: `upstream/main`
- Current sync point: [7bef190](https://github.com/ethpandaops/optimism-package/commit/7bef190d7c0b9f619438ed08b17bd5e5f51e72ff)

## Policy
- [`main`](https://github.com/agglayer/optimism-package/tree/main): Tracks `upstream/main` exactly, without modifications.
- [`overlay/main`](https://github.com/agglayer/optimism-package/tree/overlay/main): Contains our patch stack on top of `upstream/main` — this is where all fork-specific changes live.

## Patch Stack

- All fork-only changes live as a patch stack (linear, reviewed).
- Patches are ordered from the most recent to the least recent.

| # | Title | Scope | Notes |
|---|-------|-------|-------|
| 10 | feat: upgrade contracts and tooling, fix service naming and metric, support for fusaka hf | contracts, op-deployer, el/cl clients, op-batcher, op-proposer, proxyd, tests, ci | Upgrade op-deployer and contract versions, fix service naming (el/cl clients, op-batcher, op-proposer and proxyd), disable metrics registration, and add support and test configs for Fusaka hardfork |
| 09 | docs: document patches | docs | Add `FORK.md` to track fork policy and patches |
| 08 | revert: el/cl client naming | el/cl clients | Revert client renaming to avoid updating references across [kurtosis-cdk](https://github.com/0xPolygon/kurtosis-cdk), [e2e](https://github.com/agglayer/e2e), and other repositories |
| 07 | fix: ci jobs issues with op-deployer and `predeployed_allocs.json` | op-deployer, ci | Fix default configuration, test configs, and ci workflows related to op-deployer pre-deployed allocs | 
| 06 | feat: allow to disable proposer | op-proposer | Add ability to disable the op-proposer component |
| 05 | feat: pre-deployed allocs for deployer | op-deployer | Enable passing predeployed files (e.g. `predeployed-allocs.json`) to the op-deployer (*) |
| 04 | feat(op-batcher): max channel duration | op-batcher | Allow customization of the op-batcher’s maximum channel duration |
| 03 | ci: disable k8s tests | ci | Disable kubernetes tests in ci |
| 02 | ci: run tests when pushing commits to `overlay/main` | ci | Run ci tests when pushing commits to `overlay/main` for validation purposes |
| 01 | chore: update `kurtosis.yml` | kurtosis | Update `kurtosis.yml` to ensure this package is usable |

(*) We also maintain a [fork](https://github.com/leovct/optimism/tree/op-deployer/v0.4.2-cdk) of the optimism monorepo to add support for predeployed filed in the op-deployer (see this [commit](https://github.com/leovct/optimism/commit/61f2b93ea781a12e96c857b0aa08854d35274f88)).
