require 'yaml'
require 'erb'

module BoringServices
  class Configuration
    attr_reader :config, :environment

    def self.load(config_path = 'config/services.yml', environment = nil)
      env = environment || ENV['BORING_SERVICES_ENV'] || ENV['BORING_ENVIRONMENT'] || ENV['RAILS_ENV'] || 'production'
      new(config_path, env)
    end

    def initialize(config_path, environment)
      @config_path = config_path
      @environment = environment.to_s
      @config = load_config
    end

    def service_config(service_name)
      services = @config['services'] || []
      services.find { |s| s['name'] == service_name.to_s }
    end

    def service_enabled?(service_name)
      service = service_config(service_name)
      service && service['enabled'] != false
    end

    def services
      @config['services'] || []
    end

    def enabled_services
      services.reject { |s| s['enabled'] == false }
    end

    def user
      @config['user'] || 'ubuntu'
    end

    def ssh_key
      @config['ssh_key'] || '~/.ssh/id_rsa'
    end

    def forward_agent
      return @config['forward_agent'] unless @config['forward_agent'].nil?

      true
    end

    def use_ssh_agent
      return @config['use_ssh_agent'] unless @config['use_ssh_agent'].nil?

      false
    end

    def ssh_auth_methods
      (@config['ssh_auth_methods'] || ['publickey']).map(&:to_s)
    end

    def secrets
      @config['secrets'] || {}
    end

    private

    def load_config
      raise Error, "Config file not found: #{@config_path}" unless File.exist?(@config_path)

      content = File.read(@config_path)
      erb_result = ERB.new(content).result
      full_config = YAML.safe_load(erb_result, permitted_classes: [Symbol], aliases: true)

      env_config = full_config[@environment]
      raise Error, "Environment '#{@environment}' not found in config" unless env_config

      env_config
    end
  end
end
