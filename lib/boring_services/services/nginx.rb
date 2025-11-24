module BoringServices
  module Services
    class Nginx < Base
      def install
        execute_on_host do
          puts "  Installing Nginx on #{label || host}..."
          ssh_executor.install_package('nginx')
          configure_nginx
          ssh_executor.systemd_enable('nginx')
          ssh_executor.systemd_start('nginx')
        end
      end

      def uninstall
        execute_on_host do
          puts "  Uninstalling Nginx from #{label || host}..."
          ssh_executor.systemd_stop('nginx')
          ssh_executor.systemd_disable('nginx')
          ssh_executor.uninstall_package('nginx')
        end
      end

      def restart
        execute_on_host do
          puts "  Restarting Nginx on #{label || host}..."
          ssh_executor.systemd_restart('nginx')
        end
      end

      private

      def configure_nginx
        backends = service_config['backends'] || []
        listen_port = port || 80
        ssl_enabled = service_config['ssl'] == true

        upstream_servers = backends.map do |backend|
          backend_host = backend.is_a?(Hash) ? backend['host'] : backend
          backend_port = backend.is_a?(Hash) ? (backend['port'] || 3000) : 3000
          "    server #{backend_host}:#{backend_port};"
        end.join("\n")

        config_content = <<~NGINX
          upstream backend {
          #{upstream_servers}
          }

          server {
              listen #{listen_port};
              server_name _;

              location / {
                  proxy_pass http://backend;
                  proxy_set_header Host $host;
                  proxy_set_header X-Real-IP $remote_addr;
                  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                  proxy_set_header X-Forwarded-Proto $scheme;
              }

              location /health {
                  access_log off;
                  return 200 "healthy\\n";
                  add_header Content-Type text/plain;
              }
          }
        NGINX

        if ssl_enabled
          config_content += <<~NGINX

            server {
                listen 443 ssl http2;
                server_name _;

                ssl_certificate /etc/nginx/ssl/cert.pem;
                ssl_certificate_key /etc/nginx/ssl/key.pem;

                location / {
                    proxy_pass http://backend;
                    proxy_set_header Host $host;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                }
            }
          NGINX
        end

        upload! StringIO.new(config_content), '/tmp/default'
        execute :sudo, :mv, '/tmp/default', '/etc/nginx/sites-available/default'
        execute :sudo, :chown, 'root:root', '/etc/nginx/sites-available/default'
        execute :sudo, :chmod, '644', '/etc/nginx/sites-available/default'
      end
    end
  end
end
