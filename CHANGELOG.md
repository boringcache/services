# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-01-21

### Added
- Initial release of BoringServices
- Deploy infrastructure services (Memcached, Redis, HAProxy, Nginx) via SSH
- Rails integration with generators and rake tasks
- Standalone Ruby support (no Rails dependency required)
- Configuration override support for HAProxy via `custom_params`:
  - `timeout_connect`, `timeout_client`, `timeout_server`
  - `balance` algorithm (roundrobin, leastconn, etc.)
  - `health_check_path` customization
  - `ssl_ciphers` and `ssl_options` for SSL/TLS configuration
- Configuration override support for Memcached via `custom_params`:
  - `listen_address`, `max_connections`
  - `max_item_size`, `verbosity`
- Custom config template support:
  - HAProxy: `custom_config_template` option to provide your own config file
  - Memcached: `custom_config_template` option to provide your own config file
- VPN/private network support with `private_ip` field for tracking internal IPs
- Multi-host deployment support for services
- Environment-based configuration (development, staging, production)
- Secret management via environment variables or command execution
- SSL/TLS support for HAProxy with automatic certificate management
- Health checking and status monitoring
- SSH key-based authentication with configurable options

### Changed
- Made railties dependency optional for standalone Ruby usage
- Improved documentation with comprehensive examples
- Updated Ruby requirement to >= 3.0.0 (from >= 3.4.0)

### Technical Details
- Uses SSHKit for SSH operations
- Supports Ubuntu 20.04+ servers (Debian-based distributions)
- YAML-based configuration with ERB support
- Thor-based CLI interface

## [Unreleased]

### Planned
- Redis configuration override support
- Nginx configuration override support
- Service backup/restore functionality
- Multi-region deployment helpers
- Prometheus metrics integration
- Additional health check options
