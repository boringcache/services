module BoringServices
  class Installer
    attr_reader :config, :ssh_executor

    def initialize(config)
      @config = config
      @ssh_executor = SSHExecutor.new(config)
    end

    def install_all
      puts 'Installing enabled services...'
      credentials_hints = []
      config.enabled_services.each do |service|
        result = install_service_entry(service)
        credentials_hints << result if result.is_a?(Hash)
      end
      puts 'All services installed successfully!'
      print_credentials_summary(credentials_hints) if credentials_hints.any?
    end

    def install_service(service_name)
      service = config.service_config(service_name)
      raise Error, "Service #{service_name} not found in configuration" unless service
      raise Error, "Service #{service_name} is disabled" if service['enabled'] == false

      install_service_entry(service)
    end

    def install_service_entry(service)
      service_name = service['name']
      service_label = service['label'] || service['host']
      raise Error, "Service #{service_name} is disabled" if service['enabled'] == false

      puts "\nInstalling #{service_name}..."
      service_class = get_service_class(service_name)
      service_instance = service_class.new(config, ssh_executor, service)
      result = service_instance.install
      puts "✓ #{service_name} installed (#{service_label})"
      result
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

    def reconfigure_service(service_name)
      service = config.service_config(service_name)
      raise Error, "Service #{service_name} not found in configuration" unless service
      raise Error, "Service #{service_name} is disabled" if service['enabled'] == false

      puts "\nReconfiguring #{service_name}..."
      service_class = get_service_class(service_name)
      service_instance = service_class.new(config, ssh_executor, service)
      service_instance.reconfigure
      puts "✓ #{service_name} reconfigured"
    end

    def reconfigure_all
      puts 'Reconfiguring enabled services...'
      credentials_hints = []
      config.enabled_services.each do |service|
        result = reconfigure_service_entry(service)
        credentials_hints << result if result.is_a?(Hash)
      end
      puts 'All services reconfigured successfully!'
      print_credentials_summary(credentials_hints) if credentials_hints.any?
    end

    def reconfigure_service_entry(service)
      service_name = service['name']
      service_label = service['label'] || service['host']
      raise Error, "Service #{service_name} is disabled" if service['enabled'] == false

      puts "\nReconfiguring #{service_name}..."
      service_class = get_service_class(service_name)
      service_instance = service_class.new(config, ssh_executor, service)
      result = service_instance.reconfigure
      puts "✓ #{service_name} reconfigured (#{service_label})"
      result
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

    def print_credentials_summary(hints)
      puts "\n" + "=" * 50
      puts "📋 Add to Rails credentials:"
      puts "=" * 50

      # Group by service type
      grouped = hints.group_by { |h| h[:type] }

      grouped.each do |type, entries|
        puts "\n#{type}:"

        # Group by region within each type
        by_region = entries.group_by { |e| e[:region] }
        by_region.each do |region, region_entries|
          puts "  #{region}:"
          puts "    servers:"
          region_entries.each do |entry|
            puts "      - #{entry[:server]}  # #{entry[:label]}"
          end
        end
      end

      puts "\n" + "=" * 50
    end
  end
end
