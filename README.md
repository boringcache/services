# BoringServices

Deploy infrastructure services (Memcached, Redis, HAProxy, Nginx) to servers with Ruby and SSH. No Ansible, no Python, no Kubernetes.

Works standalone with any Ruby application or integrates seamlessly with Rails.

## Features

- **Memcached** - In-memory caching with configurable parameters
- **Redis** - Key-value store and cache
- **HAProxy** - Load balancer with SSL/TLS support
- **Nginx** - Web server and reverse proxy
- **Simple Configuration** - YAML files with environment support
- **Flexible Overrides** - Custom config templates or parameter overrides
- **Secret Management** - Environment variables or command execution
- **SSH Deployment** - Direct deployment to Ubuntu servers
- **Health Checks** - Monitor service status across hosts
- **VPN Support** - Optional private_ip field for VPN/WireGuard deployments
- **Rails Integration** - Generators, rake tasks, and seamless integration
- **Standalone Support** - Works with any Ruby application

## Quick Start

### Standalone

```bash
gem install boring_services
boringservices setup
boringservices status

# Target a different config/environment
BORING_SERVICES_CONFIG=config/services.staging.yml \
BORING_SERVICES_ENV=staging boringservices setup
```

### Rails Integration

```ruby
# Gemfile
gem 'boring_services'
```

```bash
# Generate config
rails generate boring_services:install

# Deploy services
rails boring_services:setup

# Deploy using a different config/environment
BORING_SERVICES_CONFIG=config/services.staging.yml BORING_SERVICES_ENV=staging \
  rails boring_services:setup

# Check health
rails boring_services:health
```

## Configuration

Create `config/services.yml`:

```yaml
production:
  user: ubuntu
  ssh_key: ~/.ssh/id_rsa
  forward_agent: true
  use_ssh_agent: false
  ssh_auth_methods:
    - publickey

  services:
    - name: memcached
      enabled: true
      hosts:
        - host: 10.8.0.20
          label: cache-a
        - host: 10.8.0.21
          label: cache-b
      port: 11211
      memory_mb: 256

    - name: redis
      enabled: true
      host: 10.8.0.22
      port: 6379
      memory_mb: 1024

    - name: haproxy
      enabled: true
      hosts:
        - 10.8.0.30
      port: 80
      stats_port: 8404
      backends:
        - host: 10.8.0.10
          port: 3000
        - host: 10.8.0.11
          port: 3000

  secrets:
    redis_password: $REDIS_PASSWORD
```

Use `host:` for a single target or `hosts:` for multiple VMs. When using `hosts`, each entry can be a simple hostname/IP or a hash with per-host overrides (e.g., `label`, `port`, or `memory_mb`).

### Service Options

#### Memcached

**Basic Configuration:**

```yaml
- name: memcached
  enabled: true
  hosts:
    - 10.8.0.20
  port: 11211         # Default: 11211
  memory_mb: 256      # Memory allocation in MB
```

**With Custom Parameters:**

```yaml
- name: memcached
  enabled: true
  host: 10.8.0.20
  port: 11211
  memory_mb: 512
  custom_params:
    listen_address: 0.0.0.0      # Default: 0.0.0.0
    max_connections: 2048         # Default: 1024
    max_item_size: 2m             # Optional: max item size
    verbosity: 2                  # Optional: 0-3 for debug output
```

**With Custom Config Template:**

```yaml
- name: memcached
  enabled: true
  host: 10.8.0.20
  custom_config_template: config/memcached.custom.conf  # Path to custom config file
```

#### Redis

```yaml
- name: redis
  enabled: true
  hosts:
    - 10.8.0.21
  port: 6379          # Default: 6379
  memory_mb: 512      # Memory allocation
```

Optional password protection via secrets:

```yaml
secrets:
  redis_password: $REDIS_PASSWORD
```

#### HAProxy

**Basic HTTP Load Balancer:**

```yaml
- name: haproxy
  enabled: true
  host: 10.8.0.30
  port: 80            # Frontend port
  stats_port: 8404    # Stats dashboard port
  backends:
    - host: 10.8.0.10
      port: 3000
    - host: 10.8.0.11
      port: 3000
```

**HTTPS with SSL Termination:**

```yaml
- name: haproxy
  enabled: true
  host: 34.123.78.90
  port: 80                # Redirects to HTTPS
  https_port: 443         # SSL/TLS port
  stats_port: 8404
  ssl: true
  ssl_cert: $(op read "op://MyVault/haproxy-ssl/certificate")
  ssl_key: $(op read "op://MyVault/haproxy-ssl/private_key")
  backends:
    - host: 192.168.1.10
      port: 3000
    - host: 192.168.1.11
      port: 3000
```

**With Custom Parameters:**

```yaml
- name: haproxy
  enabled: true
  host: 10.8.0.30
  port: 80
  stats_port: 8404
  custom_params:
    timeout_connect: 10000        # Default: 5000ms
    timeout_client: 60000          # Default: 50000ms
    timeout_server: 60000          # Default: 50000ms
    balance: leastconn             # Default: roundrobin
    health_check_path: /healthz    # Default: /health
    ssl_ciphers: CUSTOM_CIPHERS    # Custom SSL cipher suite
    ssl_options: no-sslv3          # Custom SSL options
  backends:
    - host: 10.8.0.10
      port: 3000
```

**With Custom Config Template:**

```yaml
- name: haproxy
  enabled: true
  host: 10.8.0.30
  custom_config_template: config/haproxy.custom.cfg  # Path to custom HAProxy config
  # Note: When using custom template, most other options are ignored
```

**SSL Certificate Options:**

```yaml
# Option 1: 1Password CLI
ssl_cert: $(op read "op://MyVault/haproxy-ssl/certificate")
ssl_key: $(op read "op://MyVault/haproxy-ssl/private_key")

# Option 2: Environment variables
ssl_cert: $HAPROXY_SSL_CERT
ssl_key: $HAPROXY_SSL_KEY

# Option 3: Rails credentials (Rails only)
ssl_cert: $(rails credentials:show | yq .haproxy.ssl.cert)
ssl_key: $(rails credentials:show | yq .haproxy.ssl.key)

# Option 4: Local files
ssl_cert: $(cat /path/to/cert.pem)
ssl_key: $(cat /path/to/key.pem)
```

**HAProxy Features:**
- ✅ **Config Validation** - Automatically validates HAProxy config before applying
- ✅ **SSL/TLS Support** - Automatic HTTPS setup with certificate management
- ✅ **Self-Signed Fallback** - Generates self-signed cert if none provided
- ✅ **HTTP → HTTPS Redirect** - Automatic redirect when SSL is enabled
- ✅ **Health Checks** - Configurable health check endpoint (default: GET /health)
- ✅ **Stats Dashboard** - Access at `http://your-host:8404/`
- ✅ **Custom Overrides** - Override timeouts, balance algorithms, SSL ciphers
- ✅ **Custom Templates** - Bring your own HAProxy config file

#### Nginx

```yaml
- name: nginx
  enabled: true
  hosts:
    - 10.8.0.40
  port: 80
  ssl: true           # Enable HTTPS on port 443
  backends:
    - host: 10.8.0.10
      port: 3000
```

## CLI Commands

### Install Services

```bash
boringservices install

boringservices install redis

boringservices install -e staging
```

### Check Status

```bash
boringservices status

boringservices status -e production
```

### Restart Services

```bash
boringservices restart redis

boringservices restart haproxy -e staging
```

### Uninstall Services

```bash
boringservices uninstall memcached
```

## Rails Integration

Add to your `Gemfile`:

```ruby
gem 'boring_services'
```

Generate configuration:

```bash
rails generate boring_services:install
# Creates config/services.yml

rails boring_services:setup
# Deploys all enabled services
```

Use services in your Rails app:

```ruby
Rails.application.configure do
  # Connect to Memcached
  config.cache_store = :mem_cache_store, '10.8.0.20:11211', '10.8.0.21:11211'

  # Connect to Redis for sessions
  config.session_store :redis_store,
    servers: ['redis://10.8.0.22:6379/0/session'],
    expire_after: 90.minutes
end
```

**Available Rake Tasks:**

```bash
rails boring_services:setup      # Deploy all services
rails boring_services:health     # Check service health
rails boring_services:status     # Show service status
rails boring_services:restart    # Restart all services
```

## Secrets Management

Use environment variables or command execution:

```yaml
secrets:
  # Option 1: Environment variable
  redis_password: $REDIS_PASSWORD

  # Option 2: 1Password CLI
  redis_password: $(op read "op://MyVault/redis/password")

  # Option 3: Rails credentials (Rails only)
  redis_password: $(rails credentials:show | yq .redis.password)

  # Option 4: File-based secrets
  redis_password: $(cat .secrets/redis_password)
```

## VPN/Private Network Support

BoringServices supports deploying services over VPN or private networks (e.g., WireGuard, Tailscale):

- **Public IPs** (`host`) for SSH deployment access
- **Private IPs** (`private_ip`) for service communication
- Services listen on all interfaces (0.0.0.0) by default
- Accessible via private network IPs
- No public exposure of services

**Example with Private IPs:**

```yaml
services:
  - name: redis
    host: 18.234.67.89        # ← Public IP for SSH deployment
    private_ip: 10.8.0.32     # ← Private VPN IP for connections
    label: us-east-1
    port: 6379
    memory_mb: 1024

  - name: memcached
    host: 51.15.214.103       # ← Public IP for SSH
    private_ip: 10.8.0.61     # ← Private VPN IP
    label: cache-eu
    port: 11211
    memory_mb: 256
```

Your application connects via the private IP:

```ruby
# Ruby/Rails app
Redis.new(url: 'redis://10.8.0.32:6379')

# Memcached
Dalli::Client.new('10.8.0.61:11211')
```

The `private_ip` field is optional and purely for documentation - use it to track which IPs your application should connect to.

## Health Monitoring

```bash
boringservices status
```

Output:

```
memcached: healthy
  ✓ 10.8.0.20: running
  ✓ 10.8.0.21: running

redis: healthy
  ✓ 10.8.0.22: running

haproxy: healthy
  ✓ 10.8.0.30: running
```

## Requirements

- Ruby 3.0+
- Ubuntu 20.04+ servers (Debian-based distributions)
- SSH key-based authentication
- Optional: VPN solution (WireGuard, Tailscale, etc.) for private networking

## Installation

**Standalone Ruby:**

```bash
gem install boring_services
```

**With Bundler:**

```ruby
# Gemfile
gem 'boring_services'
```

Then run:

```bash
bundle install
```

**For Rails projects**, the gem will automatically integrate with Rails and provide generators and rake tasks.

## License

MIT
