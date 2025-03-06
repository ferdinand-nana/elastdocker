#!/bin/bash

# Default to .env if no file is specified
ENV_FILE="${1:-.env}"

# Ensure the .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found!"
    exit 1
fi

# Load environment variables
set -o allexport
source "$ENV_FILE"
set +o allexport

# Initialize the MACHINE_ARCH variable
if command -v dpkg &>/dev/null; then
    MACHINE_ARCH=$(dpkg --print-architecture)
else
    MACHINE_ARCH=$(uname -m)
fi

# Set the MACHINE_ARCH as an environment variable
export MACHINE_ARCH

# Check if the host machine is Linux and set vm.max_map_count
if [[ "$(uname -s)" == "Linux" ]]; then
    sudo sysctl -w vm.max_map_count=262144
fi

# Create the docker containers
docker compose -f docker-compose.ksd.yml -f docker-compose.ksd.nodes.yml -f docker-compose.ksd.data.yml up --no-deps -d --no-recreate es0 es1 es2 kibana

# cleanup
unset MACHINE_ARCH