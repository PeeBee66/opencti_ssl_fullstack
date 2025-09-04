#!/bin/bash

# Certificate Diagnostic Script
# File: diagnose_certificates.sh
# Location: ./

echo "=== Certificate Diagnostic ==="

# Check if certificates exist
echo "1. Certificate Files Check:"
for service in redis elasticsearch minio rabbitmq opencti; do
    cert_dir="/home/opencti-admin/OpenCTI_SSL_STACK/ssl/$service"
    if [ -d "$cert_dir" ]; then
        echo "✓ $service directory exists"
        for file in ca.crt $service.crt $service.key; do
            if [ -f "$cert_dir/$file" ]; then
                echo "  ✓ $file exists"
            else
                echo "  ❌ $file missing"
            fi
        done
    else
        echo "❌ $service directory missing"
    fi
done

echo ""
echo "2. Certificate Verification Test:"
for service in redis elasticsearch minio rabbitmq opencti; do
    cert_file="/home/opencti-admin/OpenCTI_SSL_STACK/ssl/$service/$service.crt"
    ca_file="/home/opencti-admin/OpenCTI_SSL_STACK/ssl/$service/ca.crt"
    
    if [ -f "$cert_file" ] && [ -f "$ca_file" ]; then
        echo "Testing $service certificate:"
        if openssl verify -CAfile "$ca_file" "$cert_file" 2>&1; then
            echo "  ✓ Certificate chain valid"
        else
            echo "  ❌ Certificate chain invalid"
        fi
        
        # Check certificate details
        echo "  Subject: $(openssl x509 -in "$cert_file" -noout -subject 2>/dev/null || echo 'Error reading cert')"
        echo "  SAN: $(openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null || echo 'No SAN')"
    fi
done

echo ""
echo "3. Container Access Test:"
if docker ps --format "table {{.Names}}" | grep -q "opencti"; then
    echo "Testing certificate access from OpenCTI container:"
    if docker exec opencti ls -la /opt/opencti/ssl/ 2>/dev/null; then
        echo "✓ Certificates accessible in container"
        
        echo "Testing certificate readability:"
        if docker exec opencti cat /opt/opencti/ssl/ca.crt | head -n 2 2>/dev/null; then
            echo "✓ CA certificate readable"
        else
            echo "❌ CA certificate not readable"
        fi
    else
        echo "❌ Certificate directory not mounted or accessible"
    fi
else
    echo "OpenCTI container not running"
fi

echo ""
echo "4. SSL Connection Test:"
echo "Testing Redis SSL connection:"
docker exec redis redis-cli --tls --cert /tls/redis.crt --key /tls/redis.key --cacert /tls/ca.crt -h redis -p 6380 ping 2>/dev/null || echo "Redis SSL connection failed"

echo "Testing Elasticsearch SSL:"
curl -k --cert /home/opencti-admin/OpenCTI_SSL_STACK/ssl/elasticsearch/elasticsearch.crt --key /home/opencti-admin/OpenCTI_SSL_STACK/ssl/elasticsearch/elasticsearch.key https://localhost:9200/_cluster/health 2>/dev/null || echo "Elasticsearch SSL connection failed"
