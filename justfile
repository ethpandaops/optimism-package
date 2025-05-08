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

fix-style:
    kurtosis lint . --format

lint-style:
    kurtosis lint .
    
# TODO(enable more checks)
lint-code:
    kurtosis-lint \
        --checked-calls \
        --local-imports \
        main.star src/ test/

lint: lint-style lint-code

test:
    kurtosis-test .