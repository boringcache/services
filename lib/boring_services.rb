require_relative 'boring_services/version'
require_relative 'boring_services/configuration'
require_relative 'boring_services/secrets'
require_relative 'boring_services/cli'
require_relative 'boring_services/installer'
require_relative 'boring_services/ssh_executor'
require_relative 'boring_services/health_checker'
require_relative 'boring_services/service_locator'

require_relative 'boring_services/services/base'
require_relative 'boring_services/services/memcached'
require_relative 'boring_services/services/redis'
require_relative 'boring_services/services/haproxy'
require_relative 'boring_services/services/nginx'

module BoringServices
  class Error < StandardError; end

  class << self
    def root
      File.expand_path('..', __dir__)
    end

    def status
      config = Configuration.load
      health_checker = HealthChecker.new(config)
      health_checker.check_all
    end

    # Service locator instance (cached)
    def locator
      @locator ||= ServiceLocator.new
    end

    # Reset cached locator (useful for testing or config reload)
    def reset_locator!
      @locator = nil
    end

    # Convenience methods - delegate to locator

    # Get all Redis hosts as hash { label => private_ip }
    def redis_hosts
      locator.hosts_by_label('redis')
    end

    # Get Redis host by exact label
    def redis_host(label)
      locator.host_by_label('redis', label)
    end

    # Get Redis port
    def redis_port
      locator.port_for('redis') || 6379
    end

    # Build Redis URL for a label
    def redis_url(label: nil, password: nil, db: 0)
      locator.redis_url(label: label, password: password, db: db)
    end

    # Get all Memcached hosts as hash { label => private_ip }
    def memcached_hosts
      locator.hosts_by_label('memcached')
    end

    # Get Memcached host by exact label
    def memcached_host(label)
      locator.host_by_label('memcached', label)
    end

    # Get Memcached port
    def memcached_port
      locator.port_for('memcached') || 11211
    end

    # Get Memcached servers string (host:port,host:port)
    def memcached_servers(label: nil)
      locator.memcached_servers(label: label)
    end

    # Generic: get all hosts for any service as hash { label => ip }
    def hosts_for(service)
      locator.hosts_by_label(service)
    end

    # Generic: get host by exact label for any service
    def host_for(service, label)
      locator.host_by_label(service, label)
    end

    # Generic: get port for any service
    def port_for(service)
      locator.port_for(service)
    end
  end
end
require 'stringio'

# Load railtie if Rails is already loaded (safe to require Rails components)
# This avoids load order issues with ActiveSupport
require_relative 'boring_services/railtie' if defined?(Rails::Railtie)
