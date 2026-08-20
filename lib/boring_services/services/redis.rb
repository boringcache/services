module BoringServices
  module Services
    class Redis < Base
      def install
        execute_on_host do
          puts "  Installing Redis on #{label || host}..."
          ssh_executor.install_package('redis-server')
          configure_redis
          ssh_executor.systemd_enable('redis-server')
          ssh_executor.systemd_restart('redis-server')
        end
      end

      def uninstall
        execute_on_host do
          puts "  Uninstalling Redis from #{label || host}..."
          ssh_executor.systemd_stop('redis-server')
          ssh_executor.systemd_disable('redis-server')
          ssh_executor.uninstall_package('redis-server')
        end
      end

      def restart
        execute_on_host do
          puts "  Restarting Redis on #{label || host}..."
          ssh_executor.systemd_restart('redis-server')
        end
      end

      def reconfigure
        execute_on_host do
          puts "  Reconfiguring Redis on #{label || host}..."
          configure_redis
          ssh_executor.systemd_restart('redis-server')
        end
      end

      private

      def configure_redis
        memory = memory_mb || 256
        listen_port = port || 6379
        password = resolve_secret('redis_password') if config.secrets['redis_password']
        has_private_ip = !private_ip.to_s.strip.empty?
        bind_address = has_private_ip ? "127.0.0.1 #{private_ip}" : '0.0.0.0'

        config_content = <<~REDIS
          bind #{bind_address}
          port #{listen_port}
          dir /var/lib/redis
          maxmemory #{memory}mb
          maxmemory-policy allkeys-lru
          appendonly yes
          appendfsync everysec
        REDIS

        config_content += "requirepass #{password}\n" if password

        upload! StringIO.new(config_content), '/tmp/redis.conf'
        execute :sudo, :mv, '/tmp/redis.conf', '/etc/redis/redis.conf'
        execute :sudo, :chown, 'redis:redis', '/etc/redis/redis.conf'
        execute :sudo, :chmod, '640', '/etc/redis/redis.conf'

        # If using private IP (WireGuard), ensure Redis starts after WireGuard
        configure_wireguard_dependency if has_private_ip

        # Set vm.overcommit_memory for Redis background saves
        execute :sudo, :sysctl, '-w', 'vm.overcommit_memory=1'
        execute "echo 'vm.overcommit_memory = 1' | sudo tee -a /etc/sysctl.conf > /dev/null || true"
      end

      def configure_wireguard_dependency
        override_dir = '/etc/systemd/system/redis-server.service.d'
        override_content = <<~SYSTEMD
          [Unit]
          After=wg-quick@wg0.service
          Wants=wg-quick@wg0.service
        SYSTEMD

        execute :sudo, :mkdir, '-p', override_dir
        upload! StringIO.new(override_content), '/tmp/wireguard-dependency.conf'
        execute :sudo, :mv, '/tmp/wireguard-dependency.conf', "#{override_dir}/wireguard.conf"
        execute :sudo, :systemctl, 'daemon-reload'
      end
    end
  end
end
