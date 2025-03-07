#!/bin/bash

#############
# Functions #
#############

function check_docker_image_loaded() {
    local image_tag="$1"

    # Check if the image exists
    if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$image_tag"; then
        echo "✅ Docker image $image_tag is loaded successfully."
    else
        echo "❌ Docker image $image_tag is NOT found."
        echo "Try loading the image again using: docker load -i my-spring-app.tar"
    fi
}

################
# Main Process #
################

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


# Load the Docker image from the file
ES_IMAGE_TAR="ksd-es-$ELK_VERSION-$KSD_ES_VERSION-$KSD_TARGET_IMAGE_ARCH.tar"
echo "Loading Elasticsearch docker image from file: $ES_IMAGE_TAR ..."
docker load -i "$ES_IMAGE_TAR"

ES_IMAGE_DOCKER_TAG="$KSD_ES_IMAGE_NAME:$ELK_VERSION-$KSD_ES_VERSION-$KSD_TARGET_IMAGE_ARCH"
check_docker_image_loaded "$ES_IMAGE_DOCKER_TAG"


# Load the Docker image from the file
KIBANA_IMAGE_TAR="ksd-kibana-$ELK_VERSION-$KSD_ES_VERSION-$KSD_TARGET_IMAGE_ARCH.tar"
echo "Loading Kibana docker image from file: $KIBANA_IMAGE_TAR ..."
docker load -i "$KIBANA_IMAGE_TAR"

KIBANA_IMAGE_DOCKER_TAG="$KSD_KIBANA_IMAGE_NAME:$ELK_VERSION-$KSD_ES_VERSION-$KSD_TARGET_IMAGE_ARCH"
check_docker_image_loaded "$KIBANA_IMAGE_DOCKER_TAG"