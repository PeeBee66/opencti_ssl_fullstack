#!/bin/bash
# File: generate-ssl-certs.sh
# Location: /home/opencti-admin/OpenCTI_SSL_STACK/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
CA_DAYS=3650
CERT_DAYS=365
KEY_SIZE=2048
CA_KEY_SIZE=4096

# Certificate subject information
COUNTRY="US"
STATE="State"
CITY="City"
ORG="OpenCTI-Organization"
ORG_UNIT="IT-Department"

echo -e "${BLUE}OpenCTI SSL Certificate Generator${NC}"
echo -e "${BLUE}==================================${NC}"

# Clean up existing certificates
if [ -d "ssl" ]; then
    echo -e "${YELLOW}Warning: ssl/ directory exists. Remove existing certificates? (y/n)${NC}"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf ssl/
        echo -e "${GREEN}Removed existing ssl/ directory${NC}"
    else
        echo -e "${RED}Aborted. Please remove ssl/ directory manually if needed.${NC}"
        exit 1
    fi
fi

# Create SSL directory structure
echo -e "${BLUE}Creating SSL directory structure...${NC}"
mkdir -p ssl/{ca,redis,elasticsearch,minio,rabbitmq,opencti}

# Generate CA private key
echo -e "${BLUE}Generating Certificate Authority...${NC}"
openssl genrsa -out ssl/ca/ca.key ${CA_KEY_SIZE}
echo -e "${GREEN}✓ CA private key generated${NC}"

# Generate CA certificate
openssl req -new -x509 -days ${CA_DAYS} -key ssl/ca/ca.key -out ssl/ca/ca.crt \
    -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${ORG_UNIT}/CN=OpenCTI-Root-CA"
echo -e "${GREEN}✓ CA certificate generated (valid for ${CA_DAYS} days)${NC}"

# Function to generate service certificates
generate_service_cert() {
    local service=$1
    local cn=$2
    
    echo -e "${BLUE}Generating certificate for ${service}...${NC}"
    
    # Generate private key
    openssl genrsa -out ssl/${service}/${service}.key ${KEY_SIZE}
    
    # Generate certificate signing request
    openssl req -new -key ssl/${service}/${service}.key -out ssl/${service}/${service}.csr \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${ORG_UNIT}/CN=${cn}"
    
    # Create certificate signed by CA with SAN extension
    openssl x509 -req -in ssl/${service}/${service}.csr \
        -CA ssl/ca/ca.crt -CAkey ssl/ca/ca.key -CAcreateserial \
        -out ssl/${service}/${service}.crt -days ${CERT_DAYS} \
        -extensions v3_req \
        -extfile <(cat << EOF
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${cn}
DNS.2 = localhost
DNS.3 = ${service}
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
)
    
    # Clean up CSR
    rm ssl/${service}/${service}.csr
    
    # Copy CA certificate to service directory
    cp ssl/ca/ca.crt ssl/${service}/ca.crt
    
    echo -e "${GREEN}✓ Certificate generated for ${service}${NC}"
}

# Generate certificates for each service
generate_service_cert "redis" "redis"
generate_service_cert "elasticsearch" "elasticsearch"
generate_service_cert "minio" "minio"
generate_service_cert "rabbitmq" "rabbitmq"
generate_service_cert "opencti" "opencti"

# Special handling for MinIO
echo -e "${BLUE}Creating MinIO-specific certificate files...${NC}"
cp ssl/minio/minio.crt ssl/minio/public.crt
cp ssl/minio/minio.key ssl/minio/private.key
echo -e "${GREEN}✓ MinIO certificate files created${NC}"

# Set Docker-compatible permissions
echo -e "${BLUE}Setting file permissions for Docker containers...${NC}"
find ssl/ -type d -exec chmod 755 {} \;
find ssl/ -type f -name "*.crt" -exec chmod 644 {} \;
find ssl/ -type f -name "*.key" -exec chmod 644 {} \;

# Set ownership
if [ "$EUID" -eq 0 ]; then
    chown -R 1000:1000 ssl/
    echo -e "${GREEN}✓ File ownership set to 1000:1000 for Docker${NC}"
else
    chown -R $(whoami):$(whoami) ssl/ 2>/dev/null || true
    echo -e "${GREEN}✓ File ownership set to $(whoami)${NC}"
fi

echo -e "${GREEN}✓ File permissions set for Docker compatibility${NC}"

# Verify certificates
echo -e "${BLUE}Verifying generated certificates...${NC}"
for service in redis elasticsearch minio rabbitmq opencti; do
    if openssl verify -CAfile ssl/ca/ca.crt ssl/${service}/${service}.crt >/dev/null 2>&1; then
        if [ -r "ssl/${service}/${service}.crt" ] && [ -r "ssl/${service}/${service}.key" ]; then
            echo -e "${GREEN}✓ ${service} certificate verification and Docker read test passed${NC}"
        else
            echo -e "${RED}✗ ${service} certificate files not readable${NC}"
        fi
    else
        echo -e "${RED}✗ ${service} certificate verification failed${NC}"
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSL Certificate Generation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Important Notes:${NC}"
echo -e "${YELLOW}1. Certificates are Docker-compatible (644 permissions)${NC}"
echo -e "${YELLOW}2. All services have proper SAN entries${NC}"
echo -e "${YELLOW}3. CA certificate can be imported to browsers${NC}"
echo -e "${YELLOW}4. Ready for docker-compose deployment${NC}"
echo ""
echo -e "${BLUE}Certificate files location: ./ssl/${NC}"
echo -e "${GREEN}Ready to run: docker-compose up -d${NC}" 
