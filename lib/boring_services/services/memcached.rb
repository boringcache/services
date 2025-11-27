module BoringServices
  module Services
    class Memcached < Base
      def install
        execute_on_host do
          puts "  Installing Memcached on #{label || host}..."
          ssh_executor.install_package('memcached')
          configure_memcached
          ssh_executor.systemd_enable('memcached')
          ssh_executor.systemd_start('memcached')
        end
        rails_credentials_entry
      end

      def uninstall
        execute_on_host do
          puts "  Uninstalling Memcached from #{label || host}..."
          ssh_executor.systemd_stop('memcached')
          ssh_executor.systemd_disable('memcached')
          ssh_executor.uninstall_package('memcached')
        end
      end

      def restart
        execute_on_host do
          puts "  Restarting Memcached on #{label || host}..."
          ssh_executor.systemd_restart('memcached')
        end
      end

      def reconfigure
        execute_on_host do
          puts "  Reconfiguring Memcached on #{label || host}..."
          configure_memcached
          ssh_executor.systemd_restart('memcached')
        end
        rails_credentials_entry
      end

      private

      def configure_memcached
        # Check if custom config file is provided
        if service_config['custom_config_template'] && File.exist?(service_config['custom_config_template'])
          puts "    Using custom Memcached config template: #{service_config['custom_config_template']}"
          config_content = File.read(service_config['custom_config_template'])
          upload! StringIO.new(config_content), '/tmp/memcached.conf'
          execute :sudo, :mv, '/tmp/memcached.conf', '/etc/memcached.conf'
          execute :sudo, :chown, 'root:root', '/etc/memcached.conf'
          execute :sudo, :chmod, '644', '/etc/memcached.conf'
          return
        end

        memory = memory_mb || 64
        listen_port = port || 11_211

        # Get custom overrides or use defaults
        custom = service_config['custom_params'] || {}
        # Use private_ip (WireGuard) if available, otherwise custom listen_address or localhost
        listen_address = private_ip || custom['listen_address'] || '127.0.0.1'
        max_connections = custom['max_connections'] || 1024
        threads = custom['threads'] || 4
        max_item_size = custom['max_item_size'] # Optional, defaults to 1MB
        verbosity = custom['verbosity'] # Optional, no default
        run_as_user = custom['user'] || 'memcache'
        disable_udp = custom.fetch('disable_udp', true)
        modern_mode = custom.fetch('modern', true)
        slab_growth_factor = custom['slab_growth_factor'] # Optional, default 1.25

        config_content = <<~CONFIG
          # Production-ready Memcached configuration
          # Run as non-root user
          -u #{run_as_user}
          # Network settings
          -l #{listen_address}
          -p #{listen_port}
          # Memory and performance
          -m #{memory}
          -c #{max_connections}
          -t #{threads}
        CONFIG

        # Security: Disable UDP to prevent amplification attacks
        config_content += "-U 0\n" if disable_udp
        # Modern mode: enables slab rebalancing, LRU crawler, etc.
        config_content += "-o modern\n" if modern_mode
        # Custom slab growth factor (default 1.25, lower = less memory waste)
        config_content += "-f #{slab_growth_factor}\n" if slab_growth_factor
        # Max item size (default 1MB)
        config_content += "-I #{max_item_size}\n" if max_item_size
        # Verbosity for debugging
        config_content += "#{'-v' * verbosity.to_i}\n" if verbosity&.to_i&.positive?

        upload! StringIO.new(config_content), '/tmp/memcached.conf'
        execute :sudo, :mv, '/tmp/memcached.conf', '/etc/memcached.conf'
        execute :sudo, :chown, 'root:root', '/etc/memcached.conf'
        execute :sudo, :chmod, '644', '/etc/memcached.conf'
      end

      def rails_credentials_entry
        listen_port = port || 11_211
        server_address = private_ip || host
        region_label = label&.include?('us') ? 'us' : 'eu'
        {
          type: 'memcached',
          region: region_label,
          server: "#{server_address}:#{listen_port}",
          label: label || host
        }
      end
    end
  end
end
