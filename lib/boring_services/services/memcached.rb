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
        listen_address = custom['listen_address'] || '0.0.0.0'
        max_connections = custom['max_connections'] || 1024
        max_item_size = custom['max_item_size'] # Optional, no default
        verbosity = custom['verbosity'] # Optional, no default

        config_content = <<~CONFIG
          -l #{listen_address}
          -p #{listen_port}
          -m #{memory}
          -c #{max_connections}
        CONFIG

        config_content += "  -I #{max_item_size}\n" if max_item_size
        config_content += "  #{'-v' * verbosity.to_i}\n" if verbosity&.to_i&.positive?

        upload! StringIO.new(config_content), '/tmp/memcached.conf'
        execute :sudo, :mv, '/tmp/memcached.conf', '/etc/memcached.conf'
        execute :sudo, :chown, 'root:root', '/etc/memcached.conf'
        execute :sudo, :chmod, '644', '/etc/memcached.conf'
      end
    end
  end
end
