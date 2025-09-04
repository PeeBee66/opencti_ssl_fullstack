#!/bin/bash
# File: cert-manager.sh  
# Location: /opencti/

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="${SCRIPT_DIR}/ssl"

# Function to display usage
show_usage() {
    echo -e "${BLUE}OpenCTI Certificate Manager${NC}"
    echo -e "${BLUE}==========================${NC}"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  verify      - Verify all certificates"
    echo "  info        - Show certificate information"
    echo "  check-exp   - Check certificate expiration"
    echo "  renew       - Renew certificates (regenerate all)"
    echo "  clean       - Clean up all certificates"
    echo "  install-ca  - Install CA certificate to system (requires sudo)"
    echo "  help        - Show this help message"
    echo ""
}

# Function to verify certificates
verify_certificates() {
    echo -e "${BLUE}Verifying SSL certificates...${NC}"
    
    if [ ! -d "$SSL_DIR" ]; then
        echo -e "${RED}SSL directory not found. Run generate-ssl-certs.sh first.${NC}"
        return 1
    fi
    
    local verified=0
    local failed=0
    
    for service in redis elasticsearch minio rabbitmq opencti; do
        echo -n "Checking ${service}... "
        
        if [ -f "$SSL_DIR/${service}/${service}.crt" ] && [ -f "$SSL_DIR/ca/ca.crt" ]; then
            if openssl verify -CAfile "$SSL_DIR/ca/ca.crt" "$SSL_DIR/${service}/${service}.crt" >/dev/null 2>&1; then
                echo -e "${GREEN}✓ VALID${NC}"
                ((verified++))
            else
                echo -e "${RED}✗ INVALID${NC}"
                ((failed++))
            fi
        else
            echo -e "${RED}✗ MISSING${NC}"
            ((failed++))
        fi
    done
    
    echo ""
    echo -e "${GREEN}Verified: ${verified}${NC}"
    echo -e "${RED}Failed: ${failed}${NC}"
}

# Function to show certificate information
show_certificate_info() {
    echo -e "${BLUE}Certificate Information${NC}"
    echo -e "${BLUE}======================${NC}"
    
    if [ ! -d "$SSL_DIR" ]; then
        echo -e "${RED}SSL directory not found.${NC}"
        return 1
    fi
    
    # CA Information
    if [ -f "$SSL_DIR/ca/ca.crt" ]; then
        echo -e "${YELLOW}Certificate Authority:${NC}"
        openssl x509 -in "$SSL_DIR/ca/ca.crt" -noout -subject -dates
        echo ""
    fi
    
    # Service certificates
    for service in redis elasticsearch minio rabbitmq opencti; do
        if [ -f "$SSL_DIR/${service}/${service}.crt" ]; then
            echo -e "${YELLOW}${service^} Certificate:${NC}"
            openssl x509 -in "$SSL_DIR/${service}/${service}.crt" -noout -subject -dates -ext subjectAltName
            echo ""
        fi
    done
}

# Function to check certificate expiration
check_expiration() {
    echo -e "${BLUE}Checking Certificate Expiration${NC}"
    echo -e "${BLUE}===============================${NC}"
    
    if [ ! -d "$SSL_DIR" ]; then
        echo -e "${RED}SSL directory not found.${NC}"
        return 1
    fi
    
    local current_date=$(date +%s)
    
    # Check CA certificate
    if [ -f "$SSL_DIR/ca/ca.crt" ]; then
        local ca_exp=$(openssl x509 -in "$SSL_DIR/ca/ca.crt" -noout -enddate | cut -d= -f2)
        local ca_exp_epoch=$(date -d "$ca_exp" +%s)
        local ca_days_left=$(( (ca_exp_epoch - current_date) / 86400 ))
        
        echo -n "CA Certificate: "
        if [ $ca_days_left -lt 30 ]; then
            echo -e "${RED}Expires in ${ca_days_left} days${NC}"
        elif [ $ca_days_left -lt 90 ]; then
            echo -e "${YELLOW}Expires in ${ca_days_left} days${NC}"
        else
            echo -e "${GREEN}Expires in ${ca_days_left} days${NC}"
        fi
    fi
    
    # Check service certificates
    for service in redis elasticsearch minio rabbitmq opencti; do
        if [ -f "$SSL_DIR/${service}/${service}.crt" ]; then
            local cert_exp=$(openssl x509 -in "$SSL_DIR/${service}/${service}.crt" -noout -enddate | cut -d= -f2)
            local cert_exp_epoch=$(date -d "$cert_exp" +%s)
            local days_left=$(( (cert_exp_epoch - current_date) / 86400 ))
            
            echo -n "${service^} Certificate: "
            if [ $days_left -lt 30 ]; then
                echo -e "${RED}Expires in ${days_left} days${NC}"
            elif [ $days_left -lt 90 ]; then
                echo -e "${YELLOW}Expires in ${days_left} days${NC}"
            else
                echo -e "${GREEN}Expires in ${days_left} days${NC}"
            fi
        fi
    done
}

# Function to renew certificates
renew_certificates() {
    echo -e "${YELLOW}Warning: This will regenerate all certificates!${NC}"
    echo -e "${YELLOW}Docker containers will need to be restarted.${NC}"
    echo -e "${RED}Continue? (y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Renewing certificates...${NC}"
        if [ -f "$SCRIPT_DIR/generate-ssl-certs.sh" ]; then
            "$SCRIPT_DIR/generate-ssl-certs.sh"
            echo -e "${GREEN}Certificates renewed successfully!${NC}"
            echo -e "${YELLOW}Remember to restart Docker containers: docker-compose restart${NC}"
        else
            echo -e "${RED}generate-ssl-certs.sh not found!${NC}"
            return 1
        fi
    else
        echo -e "${BLUE}Certificate renewal cancelled.${NC}"
    fi
}

# Function to clean certificates
clean_certificates() {
    echo -e "${RED}Warning: This will delete ALL certificates!${NC}"
    echo -e "${RED}Continue? (y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [ -d "$SSL_DIR" ]; then
            rm -rf "$SSL_DIR"
            echo -e "${GREEN}All certificates cleaned successfully!${NC}"
        else
            echo -e "${YELLOW}No certificates found to clean.${NC}"
        fi
    else
        echo -e "${BLUE}Certificate cleanup cancelled.${NC}"
    fi
}

# Function to install CA certificate to system
install_ca_certificate() {
    echo -e "${BLUE}Installing CA certificate to system...${NC}"
    
    if [ ! -f "$SSL_DIR/ca/ca.crt" ]; then
        echo -e "${RED}CA certificate not found. Generate certificates first.${NC}"
        return 1
    fi
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}This operation requires sudo privileges.${NC}"
        echo "Run: sudo $0 install-ca"
        return 1
    fi
    
    # Detect OS and install accordingly
    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        cp "$SSL_DIR/ca/ca.crt" /usr/local/share/ca-certificates/opencti-ca.crt
        update-ca-certificates
        echo -e "${GREEN}CA certificate installed for Debian/Ubuntu${NC}"
    elif [ -f /etc/redhat-release ]; then
        # RedHat/CentOS/Fedora
        cp "$SSL_DIR/ca/ca.crt" /etc/pki/ca-trust/source/anchors/opencti-ca.crt
        update-ca-trust
        echo -e "${GREEN}CA certificate installed for RedHat/CentOS/Fedora${NC}"
    else
        echo -e "${YELLOW}Unsupported OS. Manually install: $SSL_DIR/ca/ca.crt${NC}"
    fi
}

# Main script logic
case "${1:-help}" in
    verify)
        verify_certificates
        ;;
    info)
        show_certificate_info
        ;;
    check-exp|expiration)
        check_expiration
        ;;
    renew)
        renew_certificates
        ;;
    clean)
        clean_certificates
        ;;
    install-ca)
        install_ca_certificate
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        echo -e "${RED}Unknown option: $1${NC}"
        echo ""
        show_usage
        exit 1
        ;;
esac
