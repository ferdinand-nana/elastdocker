#!/bin/bash

#############
# Functions #
#############

# Function to display the usage
function usage() {
    echo "Usage: $0 [local|prod]"
    exit 1
}

function init_dir() {
    local dir="$1"

    # Check if directory exists
    if [ ! -d "$dir" ]; then
        echo "Creating directory $dir..."
        mkdir -p "$dir"
    elif [ -n "$(ls -A "$dir")" ]; then
        read -p "Directory $dir is not empty. Would you like to continue and delete its contents? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Cleaning directory $dir..."
            rm -rf "${dir:?dir is not set}"/*
        else
            echo "Operation cancelled."
            exit 1
        fi
    fi
}

function check_files_created() {
    local dir="$1"

    # check the secrets folder if new files created under secrets/certs directory
    if [ -z "$(find "$dir" -type f ! -name '.gitkeep')" ]; then
        echo "Error: No files created in $dir directory!"
        exit 1
    fi
}

function build_docker_image() {
    local platform="$1"
    local image_name="$2"
    local dockerfile="$3"
    local context="$4"

    # Build the Docker image
    echo "Building and loading the $platform Docker image with tag $image_name ..."
    docker buildx build --platform "$platform" --build-arg ELK_VERSION="$ELK_VERSION" -t "$image_name" -f "$dockerfile" --load "$context"
}

################
# Main Process #
################

# Default the environment to 'local' if not specified
ENV="${1:-local}"
ENV_FILE=".env.${ENV}"
SECRETS_DIR="ksd-secrets"

# Ensure the .env file exists
if [ ! -f "$ENV_FILE" ]; then
    usage
fi

# Replace the .env file with the ENV_FILE
cp -f "$ENV_FILE" .env

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

# Initialize the secrets/$ENV/ssl directory
SECRETS_SSL_DIR="$SECRETS_DIR/${ENV}/ssl"
init_dir "$SECRETS_SSL_DIR"

# Copy all files from secrets directory to SECRETS_SSL_DIR
find secrets -maxdepth 1 -type f -exec cp {} "${SECRETS_SSL_DIR}/" \;

# Copy all contents from secrets/certs directory to $SECRETS_SSL_DIR
check_files_created "secrets/certs"
cp -rf secrets/certs "${SECRETS_SSL_DIR}/"
echo "Copied files from secrets/certs to ${SECRETS_SSL_DIR}..."

# Copy all contents from secrets/keystore directory to $SECRETS_SSL_DIR
check_files_created "secrets/keystore"
cp -rf secrets/keystore "${SECRETS_SSL_DIR}/"
echo "Copied files from secrets/keystore to ${SECRETS_SSL_DIR}..."


# Initialize the secrets/$ENV/http directory
SECRETS_HTTP_DIR="$SECRETS_DIR/${ENV}/http"
init_dir "$SECRETS_HTTP_DIR"

# Copy all contents from secrets/http directory to HTTP_DIR
check_files_created "secrets/http"
cp -r secrets/http/* "${SECRETS_HTTP_DIR}/"
echo "Copied files from secrets/http to ${SECRETS_HTTP_DIR}..."


# Initialize the secrets/$ENV/app directory
SECRETS_APP_DIR="$SECRETS_DIR/${ENV}/app"
init_dir "$SECRETS_APP_DIR"

# Copy all contents from secrets/http directory to APP_DIR
cp -r secrets/http/ca/* "${SECRETS_APP_DIR}/"
echo "Copied files from secrets/http to ${APP_DIR}..."

mv "${SECRETS_APP_DIR}/ca.p12" "${SECRETS_APP_DIR}/ca_$ENV.p12"
echo "$ELASTIC_USERNAME" > "${SECRETS_APP_DIR}/username.txt"
echo "$ELASTIC_PASSWORD" > "${SECRETS_APP_DIR}/password.txt"


printf "\n\n"
printf "======= Building the KSD Elasticsearch Images =======\n"
printf "=====================================================\n"
printf "\n"

# Build the KSD Elasticsearch image
build_docker_image "linux/arm64/v8" "$KSD_ES_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-arm64" "./elasticsearch/Dockerfile" "./elasticsearch"
build_docker_image "linux/amd64/v3" "$KSD_ES_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-amd64" "./elasticsearch/Dockerfile" "./elasticsearch"
printf "Elasticsearch Images built successfully! 🎉🎉🎉\n"

# Build the KSD Elasticsearch image
printf "\n\n"
build_docker_image "linux/arm64/v8" "$KSD_KIBANA_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-arm64" "./kibana/Dockerfile" "./kibana"
build_docker_image "linux/amd64/v3" "$KSD_KIBANA_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-amd64" "./kibana/Dockerfile" "./kibana"
printf "Kibana Images built successfully! 🎉🎉🎉\n"


# Creating tar file for elasticsearch image
ES_IMAGE_TAR="ksd-es-$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH.tar"
echo "Saving Elasticsearch image $KSD_ES_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH to $ES_IMAGE_TAR ..."
docker save -o "$ES_IMAGE_TAR" "$KSD_ES_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH"
echo "Elasticsearch image saved as $ES_IMAGE_TAR"

# Creating tar file for kibana image
KIBANA_IMAGE_TAR="ksd-kibana-$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH.tar"
echo "Saving Kibana image $KSD_KIBANA_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH to $KIBANA_IMAGE_TAR ..."
docker save -o "$KIBANA_IMAGE_TAR" "$KSD_KIBANA_IMAGE_NAME:$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH"
echo "Kibana image saved as $KIBANA_IMAGE_TAR"

# Building the zip file for release
CURRENT_DATE=$(date +"%Y%m%d%H%M%S")
ZIP_FILE="ksd-es-kibana_$KSD_ES_VERSION-$ELK_VERSION-$KSD_TARGET_IMAGE_ARCH_$ENV_$CURRENT_DATE.zip"
echo "Creating zip file $ZIP_FILE ..."
zip "$ZIP_FILE" .env ksd-load.sh ksd-run.sh "$ES_IMAGE_TAR" "$KIBANA_IMAGE_TAR" \
    docker-compose.ksd*.yml elasticsearch/config/* elasticsearch/scripts/* kibana/config/* \
    "ksd-secrets/${ENV}/ssl/keystore/elasticsearch.keystore" \
    "ksd-secrets/${ENV}/ssl/service_tokens" \
    "ksd-secrets/${ENV}/ssl/.env.kibana.token" \
    "ksd-secrets/${ENV}/ssl/certs/ca/ca.crt" \
    "ksd-secrets/${ENV}/ssl/certs/elasticsearch/elasticsearch.crt" \
    "ksd-secrets/${ENV}/ssl/certs/elasticsearch/elasticsearch.key" \
    "ksd-secrets/${ENV}/http/elasticsearch/http.p12" \
    "ksd-secrets/${ENV}/ssl/certs/kibana/kibana.crt" \
    "ksd-secrets/${ENV}/ssl/certs/kibana/kibana.key" \
    "ksd-secrets/${ENV}/http/kibana/elasticsearch-ca.pem"

echo "Zip file successfully created! 🎉"
zipinfo "$ZIP_FILE"

# Cleanup
rm -f .env
rm -f "$ES_IMAGE_TAR"
rm -f "$KIBANA_IMAGE_TAR"