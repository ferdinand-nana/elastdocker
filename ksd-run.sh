#!/bin/bash

# Default the environment to 'local' if not specified
ENV="${1:-local}"
ENV_FILE=".env.${ENV}"

# Ensure the .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found!"
    echo "Usage: $0 [local|prod]"
    exit 1
fi

# Replace the .env file with the ENV_FILE
cp -f "$ENV_FILE" .env

# Build the KSD Elasticsearch image
make ksd-elk-3node