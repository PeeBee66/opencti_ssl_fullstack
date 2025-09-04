# OpenCTI Docker Compose with TLS Support

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-20.10%2B-blue)](https://www.docker.com/)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-2.0%2B-blue)](https://docs.docker.com/compose/)

This repository provides a **Docker Compose setup for OpenCTI** with **full TLS/SSL integration** for secure service communication.

## 🔐 Secured Services

- **Redis** - In-memory data structure store
- **RabbitMQ** - Message broker
- **Elasticsearch (ELK)** - Search and analytics engine
- **MinIO** - Object storage
- **OpenCTI Core** - Threat intelligence platform

All inter-service communication is secured with self-signed certificates generated via included scripts.

## ⚠️ Important Warning

> **The certificates generated here are for testing and development only. Do NOT use them in production environments.**

## ✨ Features

- 🔒 Automatic generation of local Certificate Authority (CA) and service certificates
- 🐳 Secure Docker Compose configuration with TLS enabled for all services
- 🛠️ Comprehensive certificate management tools:
  - `generate-ssl-certs.sh` – Create CA and service certificates
  - `cert-manager.sh` – Verify, renew, clean, or install certificates
  - `diagnose_certificates.sh` – Run SSL connectivity and validity diagnostics
  - `validate-certificates.py` – Python-based validator with expiry and connectivity checks
- 🐰 Pre-configured RabbitMQ TLS setup
- ⚙️ Centralized configuration via `.env` file

## 🚀 Quick Start

### Prerequisites

- Docker 20.10+
- Docker Compose 2.0+
- Bash shell
- Python 3.7+ (for validation scripts)
- OpenSSL

### 1. Clone Repository

```bash
git clone https://github.com/<your-org>/<your-repo>.git
cd <your-repo>
```

### 2. Generate Certificates

Run the certificate generator script:

```bash
chmod +x generate-ssl-certs.sh
./generate-ssl-certs.sh
```

This creates a local CA and service-specific certificates under the `ssl/` directory.

### 3. Validate Certificates

Check that certificates were generated correctly:

```bash
chmod +x cert-manager.sh validate-certificates.py
./cert-manager.sh verify
python3 validate-certificates.py
```

### 4. Configure Environment

Copy and customize the environment file:

```bash
cp env.env.example env.env
# Edit env.env with your preferred settings
```

### 5. Start Services

Bring up the full OpenCTI stack:

```bash
docker-compose up -d
```

### 6. Verify Setup

Run diagnostics to confirm everything is working:

```bash
chmod +x diagnose_certificates.sh
./diagnose_certificates.sh
```

## 🔧 Certificate Management

The included certificate management tools provide comprehensive SSL certificate operations:

### Verify Certificates
```bash
./cert-manager.sh verify
```

### Show Certificate Information
```bash
./cert-manager.sh info
```

### Check Certificate Expiry
```bash
./cert-manager.sh check-exp
```

### Renew All Certificates
```bash
./cert-manager.sh renew
```

### Clean Up Certificates
```bash
./cert-manager.sh clean
```

### Python Validation Tool
```bash
python3 validate-certificates.py
```

## ⚙️ Configuration

### Environment Variables

All configuration is managed through the `env.env` file:

```bash
# OpenCTI Configuration
OPENCTI_ADMIN_EMAIL=admin@opencti.io
OPENCTI_ADMIN_PASSWORD=changeme
OPENCTI_BASE_URL=https://localhost:8080

# Database Configuration
POSTGRES_PASSWORD=changeme
POSTGRES_DB=opencti

# RabbitMQ Configuration  
RABBITMQ_DEFAULT_USER=opencti
RABBITMQ_DEFAULT_PASS=changeme

# MinIO Configuration
MINIO_ACCESS_KEY=changeme
MINIO_SECRET_KEY=changeme

# Redis Configuration
REDIS_PASSWORD=changeme
```

### SSL Configuration

Certificate settings can be customized in the generation scripts:

- **Validity Period**: 365 days (configurable)
- **Key Size**: 2048 bits RSA
- **Certificate Format**: PEM
- **CA Common Name**: OpenCTI-CA
- **Service DNS Names**: Configured per service

## 🐳 Docker Services

| Service | Port | Description |
|---------|------|-------------|
| OpenCTI | 8080 | Web interface (HTTPS) |
| Redis | 6379 | Cache (TLS) |
| RabbitMQ | 5671/15671 | Message broker (TLS) |
| Elasticsearch | 9200/9300 | Search engine (HTTPS) |
| MinIO | 9000/9001 | Object storage (HTTPS) |
| PostgreSQL | 5432 | Database |

## 🔍 Troubleshooting

### Common Issues

1. **Certificate validation errors**
   ```bash
   ./diagnose_certificates.sh
   ```

2. **Service connectivity issues**
   ```bash
   docker-compose logs <service-name>
   ```

3. **Permission denied on scripts**
   ```bash
   chmod +x *.sh
   ```

### Logs

View service logs:
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f opencti
```

## 🔄 Certificate Renewal

Certificates expire after 365 days. To renew:

1. **Automatic renewal**:
   ```bash
   ./cert-manager.sh renew
   ```

2. **Restart services**:
   ```bash
   docker-compose restart
   ```

3. **Verify renewal**:
   ```bash
   ./cert-manager.sh check-exp
   ```

## 🛡️ Security Considerations

- 🔐 Change default passwords in `env.env`
- 🔒 Use trusted certificates in production
- 🚫 Never commit certificates to version control
- 🔄 Regularly rotate certificates
- 📊 Monitor certificate expiry dates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

