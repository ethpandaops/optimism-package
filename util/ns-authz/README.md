# ns-authz

This chart deploys a lightweight namespace watcher that automatically grants the `cluster-admin` role to the default `ServiceAccount` in every namespace. It is meant to enable [kurtosis](http://kurtosis.com/) packages to run `helm` commands in Kubernetes enclaves, and is necessary as `kurtosis` runs pods using the namespace's default `ServiceAccount`, which is not typically able to modify cluster-level resources, such as `ClusterRoles`, as some Helm charts require.

> Note: this chart is not meant to be used in production environments and is strictly a stopgap measure until `kurtosis` supports running pods with configurable `ServiceAccounts`.

## Installation

```bash
helm install ns-authz ./ns-authz --namespace kube-system
```

## Usage

1. Create a new namespace:
   ```bash
   kubectl create namespace test-ns
   ```
2. Check the watcher pod logs to ensure the new namespace's `default` `ServiceAccount` was granted `cluster-admin` access:
   ```bash
   kubectl logs -l app=ns-authz -n kube-system
   ```
