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
      service = config.service_config(service_name.to_s)
      return [] unless service

      normalize_hosts(service['hosts'] || [])
    end

    # Get the connection IP for a service by region/label
    # Prefers private_ip, falls back to host
    # Label matching: "redis-eu" matches region "eu", "redis-us" matches "us"
    def host_for_region(service_name, region)
      return nil if region.to_s.strip.empty?

      hosts = hosts_for(service_name)
      host_entry = hosts.find do |h|
        label = h[:label].to_s.downcase
        region_str = region.to_s.downcase
        label == region_str || label.end_with?("-#{region_str}") || label.start_with?("#{region_str}-")
      end

      return nil unless host_entry

      connection_ip(host_entry)
    end

    # Get the first available host for a service (prefers private_ip)
    def primary_host(service_name)
      hosts = hosts_for(service_name)
      return nil if hosts.empty?

      connection_ip(hosts.first)
    end

    # Get all connection IPs for a service (prefers private_ip for each)
    def all_hosts(service_name)
      hosts_for(service_name).map { |h| connection_ip(h) }
    end

    # Get port for a service
    def port_for(service_name)
      service = config.service_config(service_name.to_s)
      service&.dig('port')
    end

    # Build a Redis URL for a region
    def redis_url(region: nil, password: nil, db: 0)
      host = region ? host_for_region('redis', region) : primary_host('redis')
      return nil unless host

      port = port_for('redis') || 6379
      auth = password.to_s.empty? ? '' : ":#{password}@"
      "redis://#{auth}#{host}:#{port}/#{db}"
    end

    # Build memcached connection string (host:port,host:port format)
    def memcached_servers(region: nil)
      hosts = if region
                host = host_for_region('memcached', region)
                host ? [host] : []
              else
                all_hosts('memcached')
              end

      return nil if hosts.empty?

      port = port_for('memcached') || 11211
      hosts.map { |h| "#{h}:#{port}" }.join(',')
    end

    private

    # Normalize hosts array - handles both simple strings and hashes
    def normalize_hosts(hosts)
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
