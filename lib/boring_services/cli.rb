# frozen_string_literal: true

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
      Installer.new(config).install_all
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'install [SERVICE]', 'Install service(s) - all services or specific service'
    option :host, type: :string, desc: 'Install only the host matching this label or address'
    def install(service_name = nil)
      config = Configuration.load(options[:config], options[:environment])
      config.only_host!(options[:host]) if options[:host]
      installer = Installer.new(config)
      service_name ? installer.install_service(service_name) : installer.install_all
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'uninstall SERVICE', 'Uninstall a specific service'
    def uninstall(service_name)
      config = Configuration.load(options[:config], options[:environment])
      Installer.new(config).uninstall_service(service_name)
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'restart SERVICE', 'Restart a specific service'
    def restart(service_name)
      config = Configuration.load(options[:config], options[:environment])
      Installer.new(config).restart_service(service_name)
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'reconfigure [SERVICE]',
         'Reconfigure service(s) - skips package installation, only updates config and restarts'
    def reconfigure(service_name = nil)
      config = Configuration.load(options[:config], options[:environment])
      installer = Installer.new(config)
      service_name ? installer.reconfigure_service(service_name) : installer.reconfigure_all
    rescue Error => e
      puts "Error: #{e.message}"
      exit 1
    end

    desc 'status', 'Check health status of all services'
    def status
      Configuration.load(options[:config], options[:environment])
      BoringServices.status.each do |service_name, result|
        puts "\n#{service_name}: #{result[:status]}"
        next unless result[:hosts]

        result[:hosts].each do |host_result|
          print_host_status(service_name, host_result)
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

    private

    def print_host_status(service_name, host_result)
      status_icon = host_result[:running] ? '✓' : '✗'
      label = host_result[:label] || host_result[:host]
      status_text = host_result[:running] ? 'running' : 'stopped'
      puts "  #{status_icon} #{label}: #{status_text}"

      return unless host_result[:stats]&.any?

      case service_name
      when 'redis' then print_redis_stats(host_result[:stats])
      when 'memcached' then print_memcached_stats(host_result[:stats])
      end
    end

    def print_redis_stats(stats)
      memory = stats['used_memory_human'] || 'N/A'
      max_memory = stats['maxmemory_human'] || 'N/A'
      clients = stats['connected_clients'] || '0'
      hit_rate = calculate_hit_rate(stats['keyspace_hits'], stats['keyspace_misses'])
      puts "      memory: #{memory} / #{max_memory}, clients: #{clients}, hit rate: #{hit_rate}%"
    end

    def print_memcached_stats(stats)
      bytes = format_bytes(stats['bytes'].to_i)
      conns = stats['curr_connections'] || '0'
      items = stats['curr_items'] || '0'
      hit_rate = calculate_hit_rate(stats['get_hits'], stats['get_misses'])
      puts "      memory: #{bytes}, connections: #{conns}, items: #{items}, hit rate: #{hit_rate}%"
    end

    def calculate_hit_rate(hits, misses)
      hits = hits.to_i
      misses = misses.to_i
      total = hits + misses
      total.positive? ? ((hits.to_f / total) * 100).round(1) : 0
    end

    def format_bytes(bytes)
      return '0B' if bytes.zero?

      units = %w[B KB MB GB]
      exp = (Math.log(bytes) / Math.log(1024)).to_i
      exp = [exp, units.length - 1].min
      "#{(bytes.to_f / (1024**exp)).round(1)}#{units[exp]}"
    end
  end
end
