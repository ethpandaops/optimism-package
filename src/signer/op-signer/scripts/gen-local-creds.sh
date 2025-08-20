#!/usr/bin/env sh

#
# This script is based on https://github.com/ethereum-optimism/infra/blob/main/op-signer/gen-local-creds.sh
# with small adjustments to fit to our use case
#

set -euo pipefail

if [ -z "${TLS_DIR-}" ]; then
    SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    TLS_DIR="$SCRIPT_DIR/tls"
fi

CERT_ORG_NAME="OP-Signer Local Org"
MOD_LENGTH=2048

# File paths
CA_CERT="$TLS_DIR/ca.crt"
CA_KEY="$TLS_DIR/ca.key"
CLIENT_TLS_KEY="tls.key"
CLIENT_TLS_CSR="tls.csr"
CLIENT_TLS_CERT="tls.crt"
CLIENT_PRIVATE_KEY="ec_private.pem"
CLIENT_OPENSSL_CNF="openssl.cnf"

generate_ca() {
    echo
    echo "Generating CA..."

    openssl req \
        -newkey "rsa:$MOD_LENGTH" \
        -new -nodes -x509 \
        -days 365 \
        -sha256 \
        -out "$CA_CERT" \
        -keyout "$CA_KEY" \
        -subj "/O=$CERT_ORG_NAME/CN=root"
}

generate_client_tls() {
    local hostname="$1"
    echo
    echo "Generating client TLS credentials for $hostname..."
    
    
    # Create a directory for this client's credentials
    local clientDir="$TLS_DIR/$hostname"
    mkdir -p "$clientDir"
    
    # Generate client key
    echo "Generating client key..."
    openssl genrsa -out "$clientDir/$CLIENT_TLS_KEY" "$MOD_LENGTH"

    # Since we are in a testing environment, we are not so strict about file permissions
    # 
    # Allowing the private key to be readable by all users
    # makes the integration with op-signer easier
    chmod 644 "$clientDir/$CLIENT_TLS_KEY"

    local confFile="$clientDir/$CLIENT_OPENSSL_CNF"
    
    # Create a config file for the CSR
    cat > "$confFile" << EOF
[req]
distinguished_name=req
[san]
subjectAltName=DNS:$hostname
EOF
    
    echo "Generating client certificate signing request..."
    openssl req \
        -new \
        -key "$clientDir/$CLIENT_TLS_KEY" \
        -sha256 \
        -out "$clientDir/$CLIENT_TLS_CSR" \
        -subj "/O=$CERT_ORG_NAME/CN=$hostname" \
        -extensions san \
        -config "$confFile"
    
    echo "Generating client certificate..."
    openssl x509 \
        -req \
        -in "$clientDir/$CLIENT_TLS_CSR" \
        -sha256 \
        -CA "$CA_CERT" \
        -CAkey "$CA_KEY" \
        -CAcreateserial \
        -out "$clientDir/$CLIENT_TLS_CERT" \
        -days 3 \
        -extensions san \
        -extfile "$confFile"
}

generate_client_signing_key() {
    local hostname="$1"

    echo
    echo "Generating private key for $hostname..."
    
    local clientDir="$TLS_DIR/$hostname"
    mkdir -p "$clientDir"
    
    openssl ecparam \
        -name secp256k1 \
        -genkey \
        -noout \
        -param_enc explicit \
        -out "$clientDir/$CLIENT_PRIVATE_KEY"
}


generate_client_credentials() {
    setup_client_hostnames "$@"
    process_clients generate_client_tls
    process_clients generate_client_signing_key
}

setup_client_hostnames() {
    CLIENT_HOSTNAMES="$*"
    if [ -z "$CLIENT_HOSTNAMES" ]; then
        CLIENT_HOSTNAMES="localhost"
    fi
    printf "\nProcessing clients: %s\n" "$CLIENT_HOSTNAMES"
}

process_clients() {
    generator="$1"
    for hostname in $CLIENT_HOSTNAMES; do
        "$generator" "$hostname"
    done
}

# Valid targets for the script
VALID_TARGETS="ca, client, client_tls, client_signing_key, all"

# Get target and client hostnames from command line arguments
if [ $# -eq 0 ]; then
    echo "Error: Target argument is required. Must be one of: $VALID_TARGETS"
    exit 1
fi

TARGET="$1"; shift

echo "----------------------------------------"
echo "Generating credentials for $TARGET"
echo "----------------------------------------"

mkdir -p "$TLS_DIR"

case "$TARGET" in
    "ca")
        generate_ca true
        ;;
    "client_tls")
        setup_client_hostnames "$@"
        process_clients generate_client_tls
        ;;
    "client_signing_key")
        setup_client_hostnames "$@"
        process_clients generate_client_signing_key
        ;;
    "client")
        generate_client_credentials "$@"
        ;;
    "all")
        generate_ca false
        generate_client_credentials "$@"
        ;;
    *)
        echo "Error: Invalid target '$TARGET'. Must be one of: $VALID_TARGETS"
        exit 1
        ;;
esac

echo "----------------------------------------"
echo "Credentials generated successfully."
echo "----------------------------------------"