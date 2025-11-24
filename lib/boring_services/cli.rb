require 'thor'

module BoringServices
  class CLI < Thor
    class_option :config, aliases: '-c', default: ENV['BORING_SERVICES_CONFIG'] || 'config/services.yml',
                          desc: 'Path to services.yml'
    class_option :environment, aliases: '-e',
                               default: ENV['BORING_SERVICES_ENV'] || ENV['BORING_ENVIRONMENT'] ||
                                        ENV['RAILS_ENV'] || 'production',
                               desc: 'Environment (production, staging, development)'

    def self.exit_on_failure?
      true
    end

    desc 'setup', 'Setup/install all services (alias for install)'
    def setup
      config = Configuration.load(options[:config], options[:environment])
      installer = Installer.new(config)
      installer.install_all
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'install [SERVICE]', 'Install service(s) - all services or specific service'
    def install(service_name = nil)
      config = Configuration.load(options[:config], options[:environment])
      installer = Installer.new(config)

      if service_name
        installer.install_service(service_name)
      else
        installer.install_all
      end
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'uninstall SERVICE', 'Uninstall a specific service'
    def uninstall(service_name)
      config = Configuration.load(options[:config], options[:environment])
      installer = Installer.new(config)
      installer.uninstall_service(service_name)
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'restart SERVICE', 'Restart a specific service'
    def restart(service_name)
      config = Configuration.load(options[:config], options[:environment])
      installer = Installer.new(config)
      installer.restart_service(service_name)
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'status', 'Check health status of all services'
    def status
      Configuration.load(options[:config], options[:environment])
      results = BoringServices.status

      results.each do |service_name, result|
        puts "\n#{service_name}: #{result[:status]}"
        next unless result[:hosts]

        result[:hosts].each do |host, host_result|
          status_icon = host_result[:running] ? '✓' : '✗'
          puts "  #{status_icon} #{host}: #{host_result[:running] ? 'running' : 'stopped'}"
        end
      end
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'version', 'Show version'
    def version
      puts "boring_services #{VERSION}"
    end
  end
end
