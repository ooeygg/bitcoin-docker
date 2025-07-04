# Bitcoin Core Docker Stack

A production-ready Docker setup for Bitcoin Core and Electrum Server with comprehensive orchestration, monitoring, and management capabilities.

## Features

- **Bitcoin Core**: Full Bitcoin node with RPC and P2P capabilities
- **Electrum Server**: High-performance Electrum server for SPV clients
- **Service Orchestration**: Docker Compose for multi-service management
- **Health Monitoring**: Built-in health checks and monitoring endpoints
- **Production Ready**: Logging, restart policies, and resource management
- **Development Tools**: Makefile with comprehensive commands

## Prerequisites

- Docker (version 20.10 or later)
- Docker Compose (version 1.28 or later)
- At least 8GB RAM (recommended 16GB+)
- 1TB+ free disk space for full Bitcoin blockchain

## Quick Start

1. **Clone and setup**:
   ```bash
   git clone
   cd bitcoin-core-docker
   cp .env.example .env
   # Edit .env with your configuration
   ```

2. **Build and start services**:
   ```bash
   make dev
   ```

3. **Check status**:
   ```bash
   make status
   make bitcoin-info
   ```

## Configuration

### Environment Variables

Copy `.env.example` to `.env` and customize:

```bash
# Bitcoin Network (mainnet, testnet, regtest)
BITCOIN_NETWORK=mainnet

# RPC Authentication
BITCOIN_RPC_USER=bitcoinrpc
BITCOIN_RPC_PASSWORD=your-secure-password

# Resource Configuration
BITCOIN_PRUNE=0  # 0 for full node, >550 for pruned node (MB)
```

### Bitcoin Configuration

Edit `bitcoin/bitcoin.conf` for advanced Bitcoin Core settings:
- Network settings (mainnet/testnet/regtest)
- RPC configuration
- ZMQ settings for real-time notifications
- Indexing options for Electrum Server

## Usage

### Core Commands

```bash
# Service Management
make up              # Start all services
make down            # Stop all services
make restart         # Restart all services
make status          # Show service status

# Building
make build-all       # Build all images
make build-bitcoin   # Build Bitcoin Core image
make build-electrs   # Build Electrum Server image

# Monitoring
make logs            # View all logs
make logs-bitcoin    # View Bitcoin Core logs
make logs-electrs    # View Electrum Server logs
make health          # Check service health

# Bitcoin Operations
make bitcoin-info    # Get node information
make bitcoin-status  # Get blockchain status
make bitcoin-cli ARGS="-getinfo"  # Run custom bitcoin-cli commands
```

### Development Workflow

```bash
# Start development environment
make dev

# Monitor services
make logs

# Test connectivity
make test

# Stop when done
make down
```

## Architecture

### Services

- **Bitcoin Core**: Full Bitcoin node with RPC server
  - Ports: 8332 (RPC), 8333 (P2P), 18332/18333 (testnet)
  - Volume: `bitcoin-data` for blockchain storage
  - Health check: `bitcoin-cli -getinfo`

- **Electrum Server**: High-performance Bitcoin indexer
  - Ports: 50001 (Electrum protocol), 4224 (monitoring)
  - Volume: `electrs-data` for index storage
  - Depends on: Bitcoin Core (with health check)

### Networking

- Custom bridge network (`bitcoin-network`)
- Service-to-service communication via service names
- Exposed ports for external access

### Data Persistence

- **bitcoin-data**: Bitcoin blockchain and configuration
- **electrs-data**: Electrum server index data
- Both volumes are bind-mounted to local directories

## Monitoring and Health Checks

### Built-in Health Checks

- **Bitcoin Core**: Uses `bitcoin-cli -getinfo`
- **Electrum Server**: HTTP endpoint check on monitoring port

### Monitoring Endpoints

- Bitcoin Core RPC: `http://localhost:8332` (authenticated)
- Electrum Server metrics: `http://localhost:4224/metrics`

### Log Management

- JSON file logging with rotation
- 100MB max file size, 3 files retained
- Access logs with `make logs`

## Maintenance

### Backup

```bash
# Stop services
make down

# Backup data directories
tar -czf bitcoin-backup-$(date +%Y%m%d).tar.gz bitcoin/data electrs/data

# Restart services
make up
```

### Updates

```bash
# Update Bitcoin Core version in bitcoin/docker/Dockerfile
# Update Electrum Server version in electrs/Dockerfile

# Rebuild and restart
make clean
make build-all
make up
```

### Cleanup

```bash
make clean           # Remove containers and images
make clean-data      # Remove all data (WARNING: destructive)
```

## Security Considerations

- **RPC Authentication**: Always use strong RPC passwords
- **Network Access**: Limit RPC access to trusted networks
- **Regular Updates**: Keep Docker images updated
- **Backup Strategy**: Implement regular backup procedures

## Troubleshooting

### Common Issues

1. **Insufficient disk space**: Ensure 500GB+ free space
2. **Memory issues**: Increase Docker memory limit to 8GB+
3. **Sync delays**: Initial blockchain sync can take 24-48 hours
4. **Port conflicts**: Ensure ports 8332, 8333, 50001 are available

### Debug Commands

```bash
# Check service logs
make logs-bitcoin
make logs-electrs

# Test Bitcoin RPC
make bitcoin-cli ARGS="-getinfo"

# Check Electrum Server status
curl http://localhost:4224/metrics

# Verify service health
make health
```

## Production Deployment

### Resource Requirements

- **CPU**: 4+ cores recommended
- **RAM**: 8GB minimum, 16GB+ recommended
- **Storage**: 500GB+ SSD recommended
- **Network**: Stable internet connection

### Security Hardening

1. Use non-root user in containers
2. Implement proper firewall rules
3. Enable log monitoring and alerting
4. Regular security updates
5. Backup encryption and off-site storage

### Performance Optimization

- Use SSD storage for better I/O performance
- Tune `dbcache` setting in bitcoin.conf
- Monitor and adjust resource limits
- Consider using external monitoring solutions

## Docker Hub Deployment

```bash
# Login to Docker Hub
docker login

# Build and push Bitcoin Core
make push-bitcoin DOCKER_REPO=username/bitcoin VERSION=v29.0

# Build and push Electrum Server
make push-electrs DOCKER_REPO=username/electrs VERSION=v0.10.9
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following best practices
4. Test thoroughly
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions:
- Check the troubleshooting section
- Review Docker and Bitcoin Core documentation
- Open an issue on GitHub