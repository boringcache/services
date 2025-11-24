module BoringServices
  class Installer
    attr_reader :config, :ssh_executor

    def initialize(config)
      @config = config
      @ssh_executor = SSHExecutor.new(config)
    end

    def install_all
      puts 'Installing enabled services...'
      config.enabled_services.each do |service|
        install_service(service['name'])
      end
      puts 'All services installed successfully!'
    end

    def install_service(service_name)
      service = config.service_config(service_name)
      raise Error, "Service #{service_name} not found in configuration" unless service
      raise Error, "Service #{service_name} is disabled" if service['enabled'] == false

      puts "\nInstalling #{service_name}..."
      service_class = get_service_class(service_name)
      service_instance = service_class.new(config, ssh_executor, service)
      service_instance.install
      puts "✓ #{service_name} installed"
    end

    def uninstall_service(service_name)
      service = config.service_config(service_name)
      raise Error, "Service #{service_name} not found in configuration" unless service

      puts "\nUninstalling #{service_name}..."
      service_class = get_service_class(service_name)
      service_instance = service_class.new(config, ssh_executor, service)
      service_instance.uninstall
      puts "✓ #{service_name} uninstalled"
    end

    def restart_service(service_name)
      service = config.service_config(service_name)
      raise Error, "Service #{service_name} not found in configuration" unless service

      puts "\nRestarting #{service_name}..."
      service_class = get_service_class(service_name)
      service_instance = service_class.new(config, ssh_executor, service)
      service_instance.restart
      puts "✓ #{service_name} restarted"
    end

    private

    def get_service_class(service_name)
      case service_name.to_s.downcase
      when 'memcached'
        Services::Memcached
      when 'redis'
        Services::Redis
      when 'haproxy'
        Services::HAProxy
      when 'nginx'
        Services::Nginx
      else
        raise Error, "Unknown service: #{service_name}"
      end
    end
  end
end
