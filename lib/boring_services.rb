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

    # Get Redis host for a region (e.g., "eu", "us")
    def redis_host(region = nil)
      region ? locator.host_for_region('redis', region) : locator.primary_host('redis')
    end

    # Get Redis port
    def redis_port
      locator.port_for('redis') || 6379
    end

    # Build Redis URL
    def redis_url(region: nil, password: nil, db: 0)
      locator.redis_url(region: region, password: password, db: db)
    end

    # Get Memcached host for a region
    def memcached_host(region = nil)
      region ? locator.host_for_region('memcached', region) : locator.primary_host('memcached')
    end

    # Get Memcached port
    def memcached_port
      locator.port_for('memcached') || 11211
    end

    # Get Memcached servers string (host:port,host:port)
    def memcached_servers(region: nil)
      locator.memcached_servers(region: region)
    end

    # Generic: get host for any service by region
    def host_for(service, region = nil)
      region ? locator.host_for_region(service, region) : locator.primary_host(service)
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
