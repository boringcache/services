require 'sshkit'
require 'sshkit/dsl'

module BoringServices
  class SSHExecutor
    include SSHKit::DSL

    attr_reader :config

    def initialize(config)
      @config = config
      setup_sshkit
    end

    def execute_on_host(host, &)
      on(formatted_host(host), &)
    end

    def execute_on_host_for_service(service, &block)
      hosts = Array(service['hosts'] || service['host']).compact
      raise Error, "No hosts defined for service #{service['name'] || 'unknown'}" if hosts.empty?

      hosts.each do |host|
        on formatted_host(host) do
          block.call(host)
        end
      end
    end

    def install_package(package, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'apt-get', 'update'
          execute :sudo, 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'install', '-y', package
        end
      else
        # Called from within SSHKit context
        backend.execute :sudo, 'apt-get', 'update'
        backend.execute :sudo, 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'install', '-y', package
      end
    end

    def uninstall_package(package, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'apt-get', 'remove', '-y', package
          execute :sudo, 'apt-get', 'autoremove', '-y'
        end
      else
        backend.execute :sudo, 'apt-get', 'remove', '-y', package
        backend.execute :sudo, 'apt-get', 'autoremove', '-y'
      end
    end

    def upload_template(template_path, destination, context = {}, host = nil)
      template = File.read(template_path)
      result = ERB.new(template).result_with_hash(context)

      if host
        execute_on_host(host) do
          upload! StringIO.new(result), destination
          execute :sudo, 'chown', 'root:root', destination
          execute :sudo, 'chmod', '644', destination
        end
      else
        backend.upload! StringIO.new(result), destination
        backend.execute :sudo, 'chown', 'root:root', destination
        backend.execute :sudo, 'chmod', '644', destination
      end
    end

    def systemd_enable(service_name, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'systemctl', 'daemon-reload'
          execute :sudo, 'systemctl', 'enable', service_name
        end
      else
        backend.execute :sudo, 'systemctl', 'daemon-reload'
        backend.execute :sudo, 'systemctl', 'enable', service_name
      end
    end

    def systemd_start(service_name, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'systemctl', 'start', service_name
        end
      else
        backend.execute :sudo, 'systemctl', 'start', service_name
      end
    end

    def systemd_stop(service_name, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'systemctl', 'stop', service_name
        end
      else
        backend.execute :sudo, 'systemctl', 'stop', service_name
      end
    end

    def systemd_restart(service_name, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'systemctl', 'restart', service_name
        end
      else
        backend.execute :sudo, 'systemctl', 'restart', service_name
      end
    end

    def systemd_disable(service_name, host = nil)
      if host
        execute_on_host(host) do
          execute :sudo, 'systemctl', 'disable', service_name
        end
      else
        backend.execute :sudo, 'systemctl', 'disable', service_name
      end
    end

    def systemd_status(service_name, host = nil)
      if host
        result = nil
        execute_on_host(host) do
          result = capture :sudo, 'systemctl', 'status', service_name, raise_on_non_zero_exit: false
        end
        result
      else
        backend.capture :sudo, 'systemctl', 'status', service_name, raise_on_non_zero_exit: false
      end
    end

    private

    def backend
      SSHKit::Backend.current ||
        raise('SSHKit backend is not available. Provide a host or call within execute_on_host.')
    end

    def setup_sshkit
      SSHKit::Backend::Netssh.configure do |ssh|
        ssh.ssh_options = {
          user: config.user,
          keys: [File.expand_path(config.ssh_key)],
          forward_agent: config.forward_agent,
          auth_methods: config.ssh_auth_methods,
          keys_only: !config.use_ssh_agent,
          use_agent: config.use_ssh_agent
        }
      end
    end

    def formatted_host(host)
      case host
      when Hash
        target_host = host['host'] || host[:host]
        raise Error, 'Host entry missing host field' unless target_host

        user = host['user'] || host[:user] || config.user
        "#{user}@#{target_host}"
      else
        host_string = host.to_s
        host_string.include?('@') ? host_string : "#{config.user}@#{host_string}"
      end
    end
  end
end
