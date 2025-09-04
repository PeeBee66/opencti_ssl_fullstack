#!/usr/bin/env python3
# File: validate-certificates.py
# Location: /opencti/

"""
OpenCTI Certificate Validator
Validates SSL certificates and checks connectivity to services
"""

import os
import ssl
import socket
import subprocess
import datetime
from pathlib import Path
from typing import Dict, List, Tuple, Optional
import sys

class Colors:
    """ANSI color codes for terminal output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

class CertificateValidator:
    def __init__(self, ssl_dir: str = "ssl"):
        self.ssl_dir = Path(ssl_dir)
        self.services = {
            'redis': 6380,
            'elasticsearch': 9200,
            'minio': 9000,
            'rabbitmq': 5671,
            'opencti': 8080
        }
    
    def validate_certificate_files(self) -> Dict[str, bool]:
        """Validate that all certificate files exist and are readable"""
        print(f"{Colors.BLUE}Validating certificate files...{Colors.NC}")
        
        results = {}
        
        # Check CA certificate
        ca_cert = self.ssl_dir / "ca" / "ca.crt"
        ca_key = self.ssl_dir / "ca" / "ca.key"
        
        if ca_cert.exists() and ca_key.exists():
            print(f"{Colors.GREEN}✓ CA certificate and key found{Colors.NC}")
            results['ca'] = True
        else:
            print(f"{Colors.RED}✗ CA certificate or key missing{Colors.NC}")
            results['ca'] = False
        
        # Check service certificates
        for service in self.services:
            cert_file = self.ssl_dir / service / f"{service}.crt"
            key_file = self.ssl_dir / service / f"{service}.key"
            ca_file = self.ssl_dir / service / "ca.crt"
            
            if cert_file.exists() and key_file.exists() and ca_file.exists():
                print(f"{Colors.GREEN}✓ {service} certificates found{Colors.NC}")
                results[service] = True
            else:
                print(f"{Colors.RED}✗ {service} certificates missing{Colors.NC}")
                results[service] = False
        
        return results
    
    def check_certificate_validity(self) -> Dict[str, Dict]:
        """Check certificate validity using OpenSSL"""
        print(f"\n{Colors.BLUE}Checking certificate validity...{Colors.NC}")
        
        results = {}
        ca_cert = self.ssl_dir / "ca" / "ca.crt"
        
        if not ca_cert.exists():
            print(f"{Colors.RED}CA certificate not found{Colors.NC}")
            return results
        
        for service in self.services:
            cert_file = self.ssl_dir / service / f"{service}.crt"
            
            if not cert_file.exists():
                results[service] = {'valid': False, 'reason': 'Certificate file not found'}
                continue
            
            try:
                # Verify certificate against CA
                cmd = ['openssl', 'verify', '-CAfile', str(ca_cert), str(cert_file)]
                result = subprocess.run(cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    print(f"{Colors.GREEN}✓ {service} certificate is valid{Colors.NC}")
                    
                    # Get certificate expiration
                    exp_cmd = ['openssl', 'x509', '-in', str(cert_file), '-noout', '-enddate']
                    exp_result = subprocess.run(exp_cmd, capture_output=True, text=True)
                    
                    if exp_result.returncode == 0:
                        exp_date_str = exp_result.stdout.strip().split('=')[1]
                        exp_date = datetime.datetime.strptime(exp_date_str, '%b %d %H:%M:%S %Y %Z')
                        days_left = (exp_date - datetime.datetime.now()).days
                        
                        results[service] = {
                            'valid': True,
                            'expires': exp_date_str,
                            'days_left': days_left
                        }
                    else:
                        results[service] = {'valid': True, 'expires': 'Unknown'}
                
                else:
                    print(f"{Colors.RED}✗ {service} certificate verification failed{Colors.NC}")
                    results[service] = {
                        'valid': False, 
                        'reason': result.stderr.strip()
                    }
                    
            except Exception as e:
                print(f"{Colors.RED}✗ Error checking {service}: {str(e)}{Colors.NC}")
                results[service] = {'valid': False, 'reason': str(e)}
        
        return results
    
    def test_ssl_connectivity(self, host: str = 'localhost') -> Dict[str, bool]:
        """Test SSL connectivity to each service"""
        print(f"\n{Colors.BLUE}Testing SSL connectivity...{Colors.NC}")
        
        results = {}
        
        for service, port in self.services.items():
            try:
                # Create SSL context
                context = ssl.create_default_context()
                context.check_hostname = False  # Since we're using self-signed certs
                context.verify_mode = ssl.CERT_NONE  # Skip verification for testing
                
                # Test connection
                with socket.create_connection((host, port), timeout=5) as sock:
                    with context.wrap_socket(sock, server_hostname=host) as ssock:
                        cert = ssock.getpeercert()
                        print(f"{Colors.GREEN}✓ {service} SSL connection successful{Colors.NC}")
                        results[service] = True
                        
            except socket.timeout:
                print(f"{Colors.YELLOW}⚠ {service} connection timeout (service may be down){Colors.NC}")
                results[service] = False
            except ConnectionRefusedError:
                print(f"{Colors.YELLOW}⚠ {service} connection refused (service not running){Colors.NC}")
                results[service] = False
            except Exception as e:
                print(f"{Colors.RED}✗ {service} SSL connection failed: {str(e)}{Colors.NC}")
                results[service] = False
        
        return results
    
    def generate_report(self, file_results: Dict, validity_results: Dict, 
                       connectivity_results: Dict) -> None:
        """Generate a comprehensive report"""
        print(f"\n{Colors.BLUE}Certificate Validation Report{Colors.NC}")
        print(f"{Colors.BLUE}============================{Colors.NC}")
        
        # Summary
        total_services = len(self.services)
        files_ok = sum(1 for v in file_results.values() if v)
        certs_valid = sum(1 for v in validity_results.values() if v.get('valid', False))
        connections_ok = sum(1 for v in connectivity_results.values() if v)
        
        print(f"\nSummary:")
        print(f"Certificate files: {files_ok}/{total_services + 1}")  # +1 for CA
        print(f"Valid certificates: {certs_valid}/{total_services}")
        print(f"SSL connections: {connections_ok}/{total_services}")
        
        # Detailed results
        print(f"\nDetailed Results:")
        for service in self.services:
            print(f"\n{service.upper()}:")
            print(f"  Files: {'✓' if file_results.get(service) else '✗'}")
            
            validity = validity_results.get(service, {})
            if validity.get('valid'):
                days_left = validity.get('days_left', 'Unknown')
                if isinstance(days_left, int):
                    if days_left < 30:
                        color = Colors.RED
                    elif days_left < 90:
                        color = Colors.YELLOW
                    else:
                        color = Colors.GREEN
                    print(f"  Validity: {color}✓ (expires in {days_left} days){Colors.NC}")
                else:
                    print(f"  Validity: {Colors.GREEN}✓{Colors.NC}")
            else:
                print(f"  Validity: {Colors.RED}✗{Colors.NC}")
            
            print(f"  Connection: {'✓' if connectivity_results.get(service) else '✗'}")
        
        # Recommendations
        print(f"\n{Colors.BLUE}Recommendations:{Colors.NC}")
        
        if files_ok < total_services + 1:
            print(f"{Colors.YELLOW}• Run generate-ssl-certs.sh to create missing certificates{Colors.NC}")
        
        if certs_valid < total_services:
            print(f"{Colors.YELLOW}• Some certificates are invalid - check OpenSSL errors above{Colors.NC}")
        
        if connections_ok < total_services:
            print(f"{Colors.YELLOW}• Some services are not accessible - check if Docker containers are running{Colors.NC}")
        
        # Check for expiring certificates
        for service, validity in validity_results.items():
            if validity.get('valid') and isinstance(validity.get('days_left'), int):
                if validity['days_left'] < 30:
                    print(f"{Colors.RED}• {service} certificate expires in {validity['days_left']} days - renew soon!{Colors.NC}")

def main():
    """Main function"""
    if len(sys.argv) > 1:
        ssl_dir = sys.argv[1]
    else:
        ssl_dir = "ssl"
    
    validator = CertificateValidator(ssl_dir)
    
    # Check if SSL directory exists
    if not validator.ssl_dir.exists():
        print(f"{Colors.RED}SSL directory '{ssl_dir}' not found.{Colors.NC}")
        print(f"{Colors.YELLOW}Run generate-ssl-certs.sh first to create certificates.{Colors.NC}")
        sys.exit(1)
    
    # Run validations
    file_results = validator.validate_certificate_files()
    validity_results = validator.check_certificate_validity()
    connectivity_results = validator.test_ssl_connectivity()
    
    # Generate report
    validator.generate_report(file_results, validity_results, connectivity_results)
    
    # Exit with appropriate code
    if all(file_results.values()) and all(v.get('valid', False) for v in validity_results.values()):
        print(f"\n{Colors.GREEN}All certificates are valid!{Colors.NC}")
        sys.exit(0)
    else:
        print(f"\n{Colors.YELLOW}Some issues found - check the report above.{Colors.NC}")
        sys.exit(1)

if __name__ == "__main__":
    main()
