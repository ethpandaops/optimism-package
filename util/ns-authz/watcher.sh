#!/bin/bash

ROLEBINDING_NAME="cluster-admin-binding"

echo "starting namespace watcher..."

ensureClusterRoleBinding() {
    local ns="$1"
    local sa="$2"

    # Strip off the leading 'namespace/'
    local nsName="${1#namespace/}"
    local clusterRoleBindingName="${ROLEBINDING_NAME}-${nsName}-${sa}"

    echo "ensuring CRB '$clusterRoleBindingName'..."

    if kubectl get clusterrolebinding "$clusterRoleBindingName" -o name >/dev/null 2>&1; then
       echo "CRB already exists, skipping"
       return
    fi

    echo "creating CRB '$clusterRoleBindingName'..."

    kubectl create clusterrolebinding "$clusterRoleBindingName" \
        --clusterrole=cluster-admin \
        --serviceaccount="${nsName}:${sa}"
}

kubectl get namespaces --watch -o name | while read ns; do
    ensureClusterRoleBinding $ns "default"
    ensureClusterRoleBinding $ns "kurtosis-api"
done
