# frozen_string_literal: true

module BoringServices
  class ServiceLocator
    attr_reader :config

    def initialize(config = nil)
      @config = config || Configuration.load
    end

    # Get all hosts for a service
    # Returns array of host hashes with :host, :private_ip, :label keys
    def hosts_for(service_name)
      services = config.services.select { |s| s['name'] == service_name.to_s }
      return [] if services.empty?

      services.flat_map { |service| normalize_service_hosts(service) }
    end

    # Get host by exact label match
    def host_by_label(service_name, label)
      hosts = hosts_for(service_name)
      host_entry = hosts.find { |h| h[:label] == label.to_s }
      return nil unless host_entry

      connection_ip(host_entry)
    end

    # Get all hosts as a hash keyed by label
    # { "redis-eu-gcp" => "10.8.0.10", "redis-us-aws" => "10.8.0.60" }
    def hosts_by_label(service_name)
      hosts_for(service_name).each_with_object({}) do |h, hash|
        hash[h[:label]] = connection_ip(h) if h[:label]
      end
    end

    # Get all connection IPs for a service (prefers private_ip for each)
    def all_ips(service_name)
      hosts_for(service_name).map { |h| connection_ip(h) }
    end

    # Get port for a service
    def port_for(service_name)
      service = config.service_config(service_name.to_s)
      service&.dig('port')
    end

    # Build a Redis URL for a specific label
    def redis_url(label: nil, password: nil, db: 0)
      host = label ? host_by_label('redis', label) : all_ips('redis').first
      return nil unless host

      port = port_for('redis') || 6379
      auth = password.to_s.empty? ? '' : ":#{password}@"
      "redis://#{auth}#{host}:#{port}/#{db}"
    end

    # Build memcached connection string (host:port,host:port format)
    def memcached_servers(label: nil)
      hosts = if label
                host = host_by_label('memcached', label)
                host ? [host] : []
              else
                all_ips('memcached')
              end

      return nil if hosts.empty?

      port = port_for('memcached') || 11_211
      hosts.map { |h| "#{h}:#{port}" }.join(',')
    end

    private

    # Normalize hosts from a service config
    # Handles: single host:, array hosts:, or hosts: as array of hashes
    def normalize_service_hosts(service)
      # Single host entry (production style)
      if service['host']
        return [{
          host: service['host'],
          private_ip: service['private_ip'],
          label: service['label']
        }]
      end

      # Array of hosts
      hosts = service['hosts'] || []
      hosts.map do |h|
        if h.is_a?(Hash)
          {
            host: h['host'],
            private_ip: h['private_ip'],
            label: h['label']
          }
        else
          { host: h.to_s, private_ip: nil, label: nil }
        end
      end
    end

    # Get connection IP - prefer private_ip if available
    def connection_ip(host_entry)
      ip = host_entry[:private_ip].to_s.strip
      ip.empty? ? host_entry[:host] : ip
    end
  end
end
