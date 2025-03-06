#!/bin/bash

# Exit on Error
set -e

OUTPUT_DIR=/secrets/http
ZIP_FILE=/usr/share/elasticsearch/elasticsearch-ssl-http.zip

printf "\n\n"
printf "======= Generating Elasticsearch HTTP =======\n"
printf "=====================================================\n"

if ! command -v unzip &>/dev/null; then
    printf "Installing Necessary Tools... \n"
    yum install -y -q -e 0 unzip;
fi

# Check if directory exists before removing contents
if [ -d "$OUTPUT_DIR" ]; then
    find $OUTPUT_DIR -type d -exec rm -rf -- {} +
    printf "Old Certificates Cleared Successfully.\n"
fi

# Create output directory
mkdir -p $OUTPUT_DIR
ls -lta "$OUTPUT_DIR"

printf "Now creating new HTTP Certifications with password %s\n" "${ELASTIC_PASSWORD}"
echo -e "N\nN\nN\n${ELASTIC_PASSWORD}\n${ELASTIC_PASSWORD}\n\nN\n\nY\n\nY\nN\n${ELASTIC_PASSWORD}\n${ELASTIC_PASSWORD}\n\n" | \
/usr/share/elasticsearch/bin/elasticsearch-certutil http --silent

if [ ! -f "$ZIP_FILE" ]; then
    printf "Error: HTTP Certifications ZIP file is not found!\n"
    exit 1
fi

printf "Check the %s created\n" "$ZIP_FILE"
ls -lta "$ZIP_FILE"

printf "Check current files and folders in %s\n" "$OUTPUT_DIR"
ls -lta "$OUTPUT_DIR"

printf "\n\n"
printf "Unzipping Certifications... \n"
unzip -qq $ZIP_FILE -d $OUTPUT_DIR;
ls -lta "$OUTPUT_DIR"

# printf "Applying Permissions to %s:0... \n" "$USER_UID"
# chown -R "$USER_UID":0 $OUTPUT_DIR
find $OUTPUT_DIR -type f -exec chmod 655 -- {} +

printf "\n"
printf "=====================================================\n"
printf "HTTP Certifications generation completed successfully.\n"
printf "=====================================================\n"
printf "\n"

printf "Verifying HTTP Keystore and Certificate...\n"
HTTP_KEYSTORE="$OUTPUT_DIR/elasticsearch/http.p12"

# Check if certificate exists
if [ ! -f "$HTTP_KEYSTORE" ]; then
    printf "Error: HTTP Keystore is not found!\n"
    exit 1
fi

# Verify PKCS12 keystore password
printf "HTTP Keystore found: %s\n" "$HTTP_KEYSTORE"
if ! openssl pkcs12 -info -in /secrets/http/elasticsearch/http.p12 -noout -passin pass:"$ELASTIC_PASSWORD" >/dev/null 2>&1; then
    printf "Error: Unable to access HTTP Keystore using password %s!\n" "$ELASTIC_PASSWORD"
    exit 1
fi

# Display keystore information
printf "Keystore Details:\n"
openssl pkcs12 -info -in /secrets/http/elasticsearch/http.p12 -noout -passin pass:"$ELASTIC_PASSWORD"


KIBANA_CERT="$OUTPUT_DIR/kibana/elasticsearch-ca.pem"
if [ ! -f "$KIBANA_CERT" ]; then
    printf "Error: Kibana Certificate is not found!\n"
    exit 1
fi

printf "\nCertificate Details:\n"
openssl x509 -in "$KIBANA_CERT" -text -noout
printf "Keystore and Certificate verification completed successfully.\n"