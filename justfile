install-ns-authz:
    helm install ns-authz util/ns-authz --namespace kube-system

uninstall-ns-authz:
    helm uninstall ns-authz --namespace kube-system

get-service-url enclaveName serviceName portId:
    kurtosis service inspect {{enclaveName}} {{serviceName}} | tail -n +2 | yq e - -o=json |\
        jq -r --arg portId {{portId}} '.Ports[$portId]' | sed 's/.*-> //'
        
open-service enclaveName serviceName:
    open "$(just get-service-url {{enclaveName}} {{serviceName}} http)"
        
open-grafana enclaveName:
    just open-service {{enclaveName}} grafana
    
# TODO(enable more checks)
lint:
    kurtosis-lint \
        --checked-calls \
        --local-imports \
        main.star src/ test/

test:
    mise exec -- kurtosis-test .

devnet-up:
    kurtosis run . --args-file network_params.yaml --enclave op-kurtosis

devnet-down:
    kurtosis enclave rm -f op-kurtosis
    kurtosis clean
