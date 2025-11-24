require_relative 'boring_services/version'
require_relative 'boring_services/configuration'
require_relative 'boring_services/secrets'
require_relative 'boring_services/cli'
require_relative 'boring_services/installer'
require_relative 'boring_services/ssh_executor'
require_relative 'boring_services/health_checker'

require_relative 'boring_services/services/base'
require_relative 'boring_services/services/memcached'
require_relative 'boring_services/services/redis'
require_relative 'boring_services/services/haproxy'
require_relative 'boring_services/services/nginx'

module BoringServices
  class Error < StandardError; end

  def self.root
    File.expand_path('..', __dir__)
  end

  def self.status
    config = Configuration.load
    health_checker = HealthChecker.new(config)
    health_checker.check_all
  end
end
require 'stringio'

# Load railtie if Rails is already loaded (safe to require Rails components)
# This avoids load order issues with ActiveSupport
if defined?(Rails::Railtie)
  require_relative 'boring_services/railtie'
end
