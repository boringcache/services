module BoringServices
  module Services
    class HAProxy < Base
      def install
        execute_on_host do
          puts "  Installing HAProxy on #{label || host}..."
          ssh_executor.install_package('haproxy')
          setup_ssl_certificates if ssl_enabled?
          configure_haproxy
          validate_config
          ssh_executor.systemd_enable('haproxy')
          ssh_executor.systemd_restart('haproxy') # Use restart instead of start to reload config
          verify_listening_ports
        end
      end

      def uninstall
        execute_on_host do
          puts "  Uninstalling HAProxy from #{label || host}..."
          ssh_executor.systemd_stop('haproxy')
          ssh_executor.systemd_disable('haproxy')
          ssh_executor.uninstall_package('haproxy')
        end
      end

      def restart
        execute_on_host do
          puts "  Restarting HAProxy on #{label || host}..."
          ssh_executor.systemd_restart('haproxy')
        end
      end

      def reconfigure
        execute_on_host do
          puts "  Reconfiguring HAProxy on #{label || host}..."
          setup_ssl_certificates if ssl_enabled?
          configure_haproxy
          validate_config
          ssh_executor.systemd_restart('haproxy')
          verify_listening_ports
        end
      end

      private

      def ssl_enabled?
        service_config['ssl'] == true || service_config['ssl_cert']
      end

      def ssl_cert_path
        '/etc/haproxy/ssl/certificate.pem'
      end

      def setup_ssl_certificates
        puts '    Setting up SSL certificates...'

        execute :sudo, :mkdir, '-p', '/etc/haproxy/ssl'
        execute :sudo, :chmod, '750', '/etc/haproxy/ssl'

        # Support multiple ways to provide certificates:
        # 1. Direct file paths: ssl_cert_path: /path/to/cert.pem
        # 2. Credentials reference: ssl_cert: "credentials:ssl.certificate"
        # 3. Inline content: ssl_cert: "-----BEGIN CERTIFICATE-----..."
        ssl_cert = resolve_ssl_content('ssl_cert')
        ssl_key = resolve_ssl_content('ssl_key')

        if ssl_cert && ssl_key
          combined_pem = "#{ssl_cert}\n#{ssl_key}"
          upload! StringIO.new(combined_pem), '/tmp/certificate.pem'
          execute :sudo, :mv, '/tmp/certificate.pem', ssl_cert_path
          execute :sudo, :chmod, '600', ssl_cert_path
          execute :sudo, :chown, 'haproxy:haproxy', ssl_cert_path
          puts '    ✓ SSL certificates installed'
        else
          puts '    ⚠ SSL enabled but no certificates provided, using self-signed'
          generate_self_signed_cert
        end
      end

      def resolve_ssl_content(key)
        value = service_config[key]
        return nil unless value

        # Check if it's a file path
        if value.start_with?('/') && File.exist?(value)
          File.read(value)
        # Check if it's a credentials reference
        elsif value.start_with?('credentials:')
          resolve_secret(value)
        # Otherwise treat as inline content
        else
          value
        end
      end

      def generate_self_signed_cert
        execute :sudo, :openssl, :req, '-x509', '-newkey', 'rsa:4096',
                '-keyout', '/tmp/key.pem',
                '-out', '/tmp/cert.pem',
                '-days', '825',
                '-nodes',
                '-subj', "\"/CN=#{host}\""
        execute :sudo, :cat, '/tmp/cert.pem', '/tmp/key.pem', '>', '/tmp/certificate.pem'
        execute :sudo, :mv, '/tmp/certificate.pem', ssl_cert_path
        execute :sudo, :chmod, '600', ssl_cert_path
        execute :sudo, :chown, 'haproxy:haproxy', ssl_cert_path
        execute :sudo, :rm, '-f', '/tmp/cert.pem', '/tmp/key.pem'
      end

      def resolve_secret(value)
        return nil unless value

        BoringServices::Secrets.resolve(value)
      end

      def validate_config
        puts '    Validating HAProxy configuration...'
        success = execute :sudo, :haproxy, '-c', '-f', '/etc/haproxy/haproxy.cfg', raise_on_error: false
        if success
          puts '    ✓ Configuration valid'
        else
          puts '    ✗ Configuration validation failed!'
          raise 'HAProxy configuration validation failed'
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      def configure_haproxy
        # Check if custom config template is provided
        if service_config['custom_config_template'] && File.exist?(service_config['custom_config_template'])
          puts "    Using custom HAProxy config template: #{service_config['custom_config_template']}"
          config_content = File.read(service_config['custom_config_template'])
          upload! StringIO.new(config_content), '/tmp/haproxy.cfg'
          execute :sudo, :mv, '/tmp/haproxy.cfg', '/etc/haproxy/haproxy.cfg'
          execute :sudo, :chown, 'root:root', '/etc/haproxy/haproxy.cfg'
          execute :sudo, :chmod, '644', '/etc/haproxy/haproxy.cfg'
          return
        end

        backends = service_config['backends'] || []
        frontend_port = port || 80
        https_port = service_config['https_port'] || 443
        stats_port = service_config['stats_port'] || 8404

        # Get custom overrides or use defaults
        custom = service_config['custom_params'] || {}
        timeout_connect = custom['timeout_connect'] || 5000
        timeout_client = custom['timeout_client'] || 50_000
        timeout_server = custom['timeout_server'] || 50_000
        balance_algorithm = custom['balance'] || 'roundrobin'
        ssl_ciphers = custom['ssl_ciphers'] || 'ECDHE+AESGCM:ECDHE+AES256:!aNULL:!MD5:!DSS'
        ssl_options = custom['ssl_options'] || 'no-sslv3 no-tlsv10 no-tlsv11'

        config_content = <<~HAPROXY
          global
              log /dev/log local0
              log /dev/log local1 notice
              chroot /var/lib/haproxy
              stats socket /run/haproxy/admin.sock mode 660 level admin
              stats timeout 30s
              user haproxy
              group haproxy
              daemon
              #{"ssl-default-bind-ciphers #{ssl_ciphers}" if ssl_enabled?}
              #{"ssl-default-bind-options #{ssl_options}" if ssl_enabled?}

          defaults
              log     global
              mode    http
              option  httplog
              option  dontlognull
              timeout connect #{timeout_connect}
              timeout client  #{timeout_client}
              timeout server  #{timeout_server}
              errorfile 400 /etc/haproxy/errors/400.http
              errorfile 403 /etc/haproxy/errors/403.http
              errorfile 408 /etc/haproxy/errors/408.http
              errorfile 500 /etc/haproxy/errors/500.http
              errorfile 502 /etc/haproxy/errors/502.http
              errorfile 503 /etc/haproxy/errors/503.http
              errorfile 504 /etc/haproxy/errors/504.http
        HAPROXY

        config_content += if ssl_enabled?
                            <<~HAPROXY

                              frontend https_front
                                  bind *:#{https_port} ssl crt #{ssl_cert_path}
                                  http-request set-header X-Forwarded-Proto https
                                  default_backend web_servers

                              frontend http_front
                                  bind *:#{frontend_port}
                                  http-request set-header X-Forwarded-Proto http
                                  default_backend web_servers
                            HAPROXY
                          else
                            <<~HAPROXY

                              frontend http_front
                                  bind *:#{frontend_port}
                                  http-request set-header X-Forwarded-Proto http
                                  default_backend web_servers
                            HAPROXY
                          end

        # Get health check path from service config, custom params, or use default
        health_check_path = service_config['health_check_path'] || custom['health_check_path'] || '/health'
        health_check_domain = service_config['health_check_domain'] || custom['health_check_domain'] || host

        config_content += <<~HAPROXY

          backend web_servers
              balance #{balance_algorithm}
              option forwardfor
              http-request set-header X-Forwarded-Host %[req.hdr(Host)]
              # Health check with proper headers
              option httpchk
              http-check send meth GET uri #{health_check_path} hdr Host #{health_check_domain}
        HAPROXY

        backends.each_with_index do |backend, idx|
          backend_host = backend.is_a?(Hash) ? backend['host'] : backend
          backend_port = backend.is_a?(Hash) ? (backend['port'] || 3000) : 3000
          config_content += "    server web#{idx + 1} #{backend_host}:#{backend_port} check\n"
        end

        config_content += <<~HAPROXY

          frontend stats
              bind *:#{stats_port}
              stats enable
              stats uri /
              stats refresh 10s
        HAPROXY

        upload! StringIO.new(config_content), '/tmp/haproxy.cfg'
        execute :sudo, :mv, '/tmp/haproxy.cfg', '/etc/haproxy/haproxy.cfg'
        execute :sudo, :chown, 'root:root', '/etc/haproxy/haproxy.cfg'
        execute :sudo, :chmod, '644', '/etc/haproxy/haproxy.cfg'
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      def verify_listening_ports
        puts '    Verifying HAProxy is listening on ports...'

        # Wait a moment for HAProxy to fully start
        sleep 2

        # Check if HAProxy is listening on expected ports
        frontend_port = port || 80
        https_port = service_config['https_port'] || 443
        stats_port = service_config['stats_port'] || 8404

        ports_to_check = [frontend_port]
        ports_to_check << https_port if ssl_enabled?
        ports_to_check << stats_port

        ports_to_check.each do |check_port|
          result = execute :sudo, :ss, '-tlnp', '|', :grep, '-E', "':#{check_port} '", raise_on_error: false
          if result
            puts "    ✓ Port #{check_port} is listening"
          else
            puts "    ✗ Warning: Port #{check_port} is not listening"
          end
        end

        puts '    ✓ HAProxy port verification complete'
      end
    end
  end
end
