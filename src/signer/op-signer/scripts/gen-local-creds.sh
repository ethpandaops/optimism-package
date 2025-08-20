#!/usr/bin/env sh

set -euo pipefail

if [ -z "$TLS_DIR" ]; then
    SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    TLS_DIR="$SCRIPT_DIR/tls"
fi

OPENSSL_IMAGE="alpine/openssl:3.3.3"

USER_UID=$(id -u)
USER_GID=$(id -g)

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

# Check if we should use Docker (default to true if not set)
USE_DOCKER=${OP_SIGNER_GEN_TLS_DOCKER:-true}

# Helper function to run openssl commands
run_openssl() {
    if [ "$USE_DOCKER" = "true" ]; then
        docker run --rm \
            -v "$TLS_DIR:$TLS_DIR" \
            -u "$USER_UID:$USER_GID" \
            "$OPENSSL_IMAGE" "$@"
    else
        # Check if openssl is available locally
        if ! command -v openssl &> /dev/null; then
            echo "Error: OpenSSL is not installed locally. Please install OpenSSL or use Docker by setting OP_SIGNER_GEN_TLS_DOCKER=true"
            exit 1
        fi
        openssl "$@"
    fi
}

generate_ca() {
    local force="$1"
    [ "$force" = "true" ] || [ ! -f "$CA_CERT" ] || return 0

    echo
    echo "Generating CA..."

    run_openssl req -newkey "rsa:$MOD_LENGTH" \
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
    run_openssl genrsa -out "$clientDir/$CLIENT_TLS_KEY" "$MOD_LENGTH"

    local confFile="$clientDir/$CLIENT_OPENSSL_CNF"
    
    # Create a config file for the CSR
    cat > "$confFile" << EOF
[req]
distinguished_name=req
[san]
subjectAltName=DNS:$hostname
EOF
    
    echo "Generating client certificate signing request..."
    run_openssl req -new -key "$clientDir/$CLIENT_TLS_KEY" \
        -sha256 \
        -out "$clientDir/$CLIENT_TLS_CSR" \
        -subj "/O=$CERT_ORG_NAME/CN=$hostname" \
        -extensions san \
        -config "$confFile"
    
    echo "Generating client certificate..."
    run_openssl x509 -req -in "$clientDir/$CLIENT_TLS_CSR" \
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
    run_openssl ecparam -name secp256k1 -genkey -noout -param_enc explicit \
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
echo "!!!! DO NOT USE IN PRODUCTION !!!!!"
echo "This script is meant for development/testing ONLY."
echo "Generating credentials..."
echo
echo "Target: $TARGET"
echo "Using Docker: $USE_DOCKER"
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
echo
echo "Credentials generated successfully."
echo "----------------------------------------"