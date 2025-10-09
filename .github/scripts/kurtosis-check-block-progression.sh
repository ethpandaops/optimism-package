#!/usr/bin/env bash

# 
# 
# This is a test script used mostly in the CI pipeline
# 
# It will search for all EL clients in a specified kurtosis enclave
# and will check whether their blocks advance in a reasonable amount of time
# 
# Usage:
# 
# ./kurtosis-check-enclave-block-creation.sh <ENCLAVE_NAME> [TARGET_BLOCK_NUMBER] [NUMBER_OF_NAPS]
# 
# 

# Just so that we don't repeat ourselves
ENCLAVES_API_URL=http://127.0.0.1:9779/api/enclaves

# We pass the enclave name and the target block as script arguments
ENCLAVE_NAME=$1
if [ -z "$ENCLAVE_NAME" ]; then
    echo "Please specify the enclave name as the first parameter"
    exit 1
fi

# We default the target block to a good round 50
TARGET_BLOCK=$2
if [ -z "$TARGET_BLOCK" ]; then
    TARGET_BLOCK=50
fi

# The number of sleeps the script will take
NUM_NAPS=$3
if [ -z "$NUM_NAPS" ]; then
    NUM_NAPS=100
fi

echo "Checking whether EL clients in enclave $ENCLAVE_NAME reach target block $TARGET_BLOCK (latest, safe, and finalized) in reasonable time ($NUM_NAPS of 5s)"

# Get the enclave UUID from the API
# 
# The API reponse is a JSON object with UUIDs as keys. To get the UUID we need to find a value
# with a matching "name" property.
# 
# The "| values" at the end of the jq transformation will convert null to an empty string
ENCLAVE_ID=$(curl -s $ENCLAVES_API_URL | jq -r 'to_entries | map(select(.value.name == "'$ENCLAVE_NAME'")) | .[0].key | values')

# Make sure we got something
if [ -z "$ENCLAVE_ID" ]; then
    echo "No enclave found for enclave $ENCLAVE_NAME"
    exit 1
fi

echo "Got enclave UUID: $ENCLAVE_ID"

# Now get all the EL client services
# 
# We assume the convention is to name them op-el-xxx
ENCLAVE_SERVICES=$(curl -s $ENCLAVES_API_URL/$ENCLAVE_ID/services)
ENCLAVE_EL_SERVICES=$(echo $ENCLAVE_SERVICES | jq -r 'to_entries | map(select(.key | startswith("op-el-"))) | map(.value)')

# Now get the EL client names and RPC ports and arrange them into single-line space-delimited strings
# 
# This is useful for bash iteration below
ENCLAVE_EL_SERVICE_NAMES=$(echo $ENCLAVE_EL_SERVICES | jq -r 'map(.name) | join(" ")')
ENCLAVE_EL_SERVICE_RPC_PORTS=$(echo $ENCLAVE_EL_SERVICES | jq -r 'map(.public_ports.rpc.number) | join(" ")')

# Make sure we got something
if [ -z "$ENCLAVE_EL_SERVICE_NAMES" ]; then
    echo "No EL clients found for enclave $ENCLAVE_NAME"
    exit 1
fi

echo "Got enclave EL services: $ENCLAVE_EL_SERVICE_NAMES"
echo "Got enclave EL RPC ports: $ENCLAVE_EL_SERVICE_RPC_PORTS"

# Convert the lists into bash arrays
ENCLAVE_EL_SERVICE_NAMES_ARRAY=($ENCLAVE_EL_SERVICE_NAMES)
ENCLAVE_EL_SERVICE_RPC_PORTS_ARRAY=($ENCLAVE_EL_SERVICE_RPC_PORTS)

# Now check that the clients advance
for STEP in $(seq 1 $NUM_NAPS); do
    echo "Check $STEP/$NUM_NAPS"
    
    # Iterate over the names/RPC ports arrays
    for I in "${!ENCLAVE_EL_SERVICE_NAMES_ARRAY[@]}"; do
        SERVICE_NAME=${ENCLAVE_EL_SERVICE_NAMES_ARRAY[$I]}
        SERVICE_RPC_PORT=${ENCLAVE_EL_SERVICE_RPC_PORTS_ARRAY[$I]}
        SERVICE_RPC_URL="http://127.0.0.1:$SERVICE_RPC_PORT"

        # Get latest, safe and finalized blocks
        LATEST_BLOCK=$(cast bn --rpc-url $SERVICE_RPC_URL)
        SAFE_BLOCK=$(cast bn safe --rpc-url $SERVICE_RPC_URL)
        FINALIZED_BLOCK=$(cast bn finalized --rpc-url $SERVICE_RPC_URL)
        echo "Got blocks for $SERVICE_NAME: latest=$LATEST_BLOCK, safe=$SAFE_BLOCK, finalized=$FINALIZED_BLOCK"

        # Check whether we reached the target block for all three types
        if [ "$LATEST_BLOCK" -gt "$TARGET_BLOCK" ] && [ "$SAFE_BLOCK" -gt "$TARGET_BLOCK" ] && [ "$FINALIZED_BLOCK" -gt "$TARGET_BLOCK" ]; then
            echo "Target block $TARGET_BLOCK reached for all block types (latest, safe, finalized) for $SERVICE_NAME"
            
            # If so, we remove the service from the array
            unset ENCLAVE_EL_SERVICE_NAMES_ARRAY[$I]
            unset ENCLAVE_EL_SERVICE_RPC_PORTS_ARRAY[$I]
        fi
    done

    # Since we used unset, we need to reindex the arrays, we need to remove any gaps left behind
    ENCLAVE_EL_SERVICE_NAMES_ARRAY=("${ENCLAVE_EL_SERVICE_NAMES_ARRAY[@]}")
    ENCLAVE_EL_SERVICE_RPC_PORTS_ARRAY=("${ENCLAVE_EL_SERVICE_RPC_PORTS_ARRAY[@]}")

    # Now we check whether the arrays are empty
    # 
    # This means all target blocks have been reached for all block types and we can exit fine
    if [ ${#ENCLAVE_EL_SERVICE_NAMES_ARRAY[@]} -eq 0 ]; then
        echo "All target blocks have been reached for all block types (latest, safe, finalized). Exiting."
        exit 0
    fi

    sleep 5
done

echo "Target blocks have not been reached for all block types (latest, safe, finalized) for the following services:"

for I in "${!ENCLAVE_EL_SERVICE_NAMES_ARRAY[@]}"; do
    SERVICE_NAME=${ENCLAVE_EL_SERVICE_NAMES_ARRAY[$I]}

    echo "  $SERVICE_NAME"
done

exit 1