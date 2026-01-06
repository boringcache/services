# frozen_string_literal: true

module BoringServices
  class HealthChecker
    REDIS_INFO_KEYS = %w[used_memory_human connected_clients keyspace_hits keyspace_misses maxmemory_human].freeze

    attr_reader :config, :ssh_executor

    def initialize(config)
      @config = config
      @ssh_executor = SSHExecutor.new(config)
    end

    def check_all
      results = {}
      config.enabled_services.each do |service|
        results[service['name']] = check_service(service)
      end
      results
    end

    def check_service(service)
      hosts = extract_hosts(service)
      return { status: 'no_host' } if hosts.empty?

      host_results = hosts.map { |host_config| check_host(service['name'], host_config) }
      {
        status: host_results.all? { |r| r[:running] } ? 'healthy' : 'unhealthy',
        hosts: host_results
      }
    end

    private

    def extract_hosts(service)
      return Array(service['hosts']) if service['hosts']
      return [service['host']] if service['host']

      []
    end

    def check_host(service_name, host_config)
      host = host_config.is_a?(Hash) ? (host_config['host'] || host_config[:host]) : host_config
      label = host_config.is_a?(Hash) ? (host_config['label'] || host_config[:label]) : nil

      result = check_service_on_host(service_name, host)
      result[:label] = label
      result[:host] = host
      result
    end

    def check_service_on_host(service_name, host)
      systemd_service = service_name == 'redis' ? 'redis-server' : service_name
      status_output = ssh_executor.systemd_status(systemd_service, host)
      running = status_output.to_s.include?('active (running)')

      result = { running: running, message: status_output.to_s }
      result[:stats] = fetch_stats(service_name, host) if running
      result
    rescue StandardError => e
      { running: false, message: e.message }
    end

    def fetch_stats(service_name, host)
      case service_name
      when 'redis' then get_redis_stats(host)
      when 'memcached' then get_memcached_stats(host)
      else {}
      end
    end

    def get_redis_stats(host)
      password = config.secrets['redis_password']
      password_resolved = password ? Secrets.resolve(password) : nil

      result = {}
      ssh_executor.execute_on_host(host) do
        args = ['redis-cli']
        args += ['-a', password_resolved] if password_resolved
        args << 'INFO'

        info = capture(*args, raise_on_non_zero_exit: false)
        info.to_s.each_line do |line|
          key, value = line.strip.split(':')
          result[key] = value if key && value && REDIS_INFO_KEYS.include?(key)
        end
      end
      result
    rescue StandardError
      {}
    end

    def get_memcached_stats(host)
      result = {}
      ssh_executor.execute_on_host(host) do
        stats = capture(:bash, '-c', "echo 'stats' | nc localhost 11211", raise_on_non_zero_exit: false)
        stats.to_s.each_line do |line|
          parts = line.strip.split
          next unless parts[0] == 'STAT' && parts.length >= 3
          next unless %w[bytes curr_connections get_hits get_misses curr_items].include?(parts[1])

          result[parts[1]] = parts[2]
        end
      end
      result
    rescue StandardError
      {}
    end
  end
end
