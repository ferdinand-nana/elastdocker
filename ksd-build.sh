#!/bin/bash

# Default the environment to 'local' if not specified
ENV="${1:-local}"
ENV_FILE=".env.${ENV}"
SECRETS_DIR="solomon-secrets"

# Ensure the .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found!"
    echo "Usage: $0 [local|prod]"
    exit 1
fi

# Replace the .env file with the ENV_FILE
cp -f "$ENV_FILE" .env

if [ -n "$(ls -A "$CERTS_DIR")" ]; then
    read -p "Directory $CERTS_DIR is not empty. Would you like to continue and delete its contents? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning directory $CERTS_DIR..."
        rm -rf "${CERTS_DIR:?CERTS_DIR is not set}"/*
    else
        echo "Operation cancelled."
        exit 1
    fi
fi

# Load environment variables
set -o allexport
# shellcheck source=/dev/null
source "$ENV_FILE"
set +o allexport

# Ensure Docker Buildx is enabled
if ! docker buildx version > /dev/null 2>&1; then
    echo "Error: Docker Buildx is not enabled! Run: docker buildx create --use"
    exit 1
fi

# Run the make setup
echo "Running 'make setup'..."
make setup


# check the secrets folder if new files created under secrets/certs directory
if [ -z "$(find secrets/certs -type f ! -name '.gitkeep')" ]; then
    echo "Error: No certificate files found in secrets/certs directory!"
    exit 1
fi

# check the secrets folder if new files created under secrets/keystore directory
if [ -z "$(ls -A secrets/keystore)" ]; then
    echo "Error: No keystore files found in secrets/keystore directory!"
    exit 1
fi

CERTS_DIR="$SECRETS_DIR/${ENV}/ssl"
# Check if directory exists
if [ ! -d "$CERTS_DIR" ]; then
    echo "Creating directory $CERTS_DIR..."
    mkdir -p "$CERTS_DIR"
elif [ -n "$(ls -A "$CERTS_DIR")" ]; then
    read -p "Directory $CERTS_DIR is not empty. Would you like to continue and delete its contents? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning directory $CERTS_DIR..."
        rm -rf "${CERTS_DIR:?CERTS_DIR is not set}"/*
    else
        echo "Operation cancelled."
        exit 1
    fi
fi

# Copy all contents from secrets/certs and secrets/keystore directories to CERTS_DIR
echo "Copying files from secrets/certs and secrets/keystore to ${CERTS_DIR}..."
cp -rf secrets/certs "${CERTS_DIR}/"
cp -rf secrets/keystore "${CERTS_DIR}/"
find secrets -type f -exec cp {} "${CERTS_DIR}/" \;


HTTP_DIR="$SECRETS_DIR/${ENV}/http"
# Check if directory exists
if [ ! -d "$HTTP_DIR" ]; then
    echo "Creating directory $HTTP_DIR..."
    mkdir -p "$HTTP_DIR"
elif [ -n "$(ls -A "$HTTP_DIR")" ]; then
    read -p "Directory $HTTP_DIR is not empty. Would you like to continue and delete its contents? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning directory $HTTP_DIR..."
        rm -rf "${HTTP_DIR:?HTTP_DIR is not set}"/*
    else
        echo "Operation cancelled."
        exit 1
    fi
fi

# Copy all contents from secrets/http directory to HTTP_DIR
echo "Copying files from secrets/http to ${HTTP_DIR}..."
cp -r secrets/http/* "${HTTP_DIR}/"

APP_DIR="$SECRETS_DIR/${ENV}/app"
# Check if directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "Creating directory $APP_DIR..."
    mkdir -p "$APP_DIR"
elif [ -n "$(ls -A "$APP_DIR")" ]; then
    read -p "Directory $APP_DIR is not empty. Would you like to continue and delete its contents? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleaning directory $APP_DIR..."
        rm -rf "${APP_DIR:?APP_DIR is not set}"/*
    else
        echo "Operation cancelled."
        exit 1
    fi
fi

# Copy all contents from secrets/http directory to APP_DIR
echo "Copying files from secrets/http to ${APP_DIR}..."
cp -r secrets/http/ca/* "${APP_DIR}/"
mv "${APP_DIR}/ca.p12" "${APP_DIR}/ca_$ENV.p12"
echo "$ELASTIC_USERNAME" > "${APP_DIR}/username.txt"
echo "$ELASTIC_PASSWORD" > "${APP_DIR}/password.txt"


printf "\n\n"
printf "======= Building the KSD Elasticsearch Image =======\n"
printf "====================================================\n"
printf "\n"

# Build the KSD Elasticsearch image
make ksd-build