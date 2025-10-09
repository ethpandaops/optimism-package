#!/usr/bin/env sh

# Get private key from the script arguments
if [ $# -ne 1 ]; then
    echo "Error: Private key argument is required."
    exit 1
fi

# We grab the private key from the arguments
PRIVATE_KEY="$1"; shift

# We convert it to ASCII
PRIVATE_KEY_ASCII=$(echo -n "$PRIVATE_KEY" | xxd -r -p)

# And pad it 
PRIVATE_KEY_PREFIX="\\x30\\x2e\\x02\\x01\\x01\\x04\\x20"
PRIVATE_KEY_SUFFIX="\\xa0\\x07\\x06\\x05\\x2b\\x81\\x04\\x00\\x0a"
PRIVATE_KEY_WRAPPED="${PRIVATE_KEY_PREFIX}${PRIVATE_KEY_ASCII}${PRIVATE_KEY_SUFFIX}"

# And finally we create the EC encoded private key
printf "%b" "$PRIVATE_KEY_WRAPPED" | openssl ec -inform DER -outform PEM