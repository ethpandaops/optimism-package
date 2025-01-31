# ns-authz Helm Chart

This chart deploys a lightweight namespace watcher that automatically grants the \`cluster-admin\` role to the default ServiceAccount in every new namespace.

## Features

- Automatic Namespace Detection
- RoleBinding Creation for each new namespace
- Idempotent operation
- Minimal logging
- Self-contained using a lightweight kubectl image
- Helm-based install/uninstall

## Installation

```bash
helm install ns-authz ./ns-authz --namespace kube-system
```

## Uninstallation

```bash
helm uninstall ns-authz --namespace kube-system
```

## Verification

1. Create a new namespace:
   ```bash
   kubectl create namespace test-ns
   ```
2. Check the watcher pod logs:
   ```bash
   kubectl logs -l app=ns-authz -n kube-system
   ```
