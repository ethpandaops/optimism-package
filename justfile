install-ns-authz:
    helm install ns-authz util/ns-authz --namespace kube-system

uninstall-ns-authz:
    helm uninstall ns-authz --namespace kube-system
