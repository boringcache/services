# frozen_string_literal: true

require 'sshkit'
require 'sshkit/dsl'
require 'net/ssh/proxy/command'
require 'shellwords'

module BoringServices
  class SSHExecutor
    include SSHKit::DSL

    DPKG_LOCK_MAX_WAIT = 300
    DPKG_LOCK_INTERVAL = 10

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
          wait_for_dpkg_lock
          execute :sudo, 'apt-get', 'update'
          execute :sudo, 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'install', '-y', package
        end
      else
        wait_for_dpkg_lock
        backend.execute :sudo, 'apt-get', 'update'
        backend.execute :sudo, 'DEBIAN_FRONTEND=noninteractive', 'apt-get', 'install', '-y', package
      end
    end

    def wait_for_dpkg_lock
      elapsed = 0

      loop do
        break unless backend.test '[ -f /var/lib/dpkg/lock-frontend ]'

        processes = backend.capture(:sudo, :fuser, '/var/lib/dpkg/lock-frontend', '2>/dev/null',
                                    raise_on_non_zero_exit: false).strip
        break if processes.empty?

        if elapsed >= DPKG_LOCK_MAX_WAIT
          puts "    ⚠ Warning: dpkg lock still held after #{DPKG_LOCK_MAX_WAIT}s, proceeding anyway..."
          break
        end

        puts "    ⏳ Waiting for dpkg lock to be released (#{elapsed}s elapsed)..."
        sleep DPKG_LOCK_INTERVAL
        elapsed += DPKG_LOCK_INTERVAL
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
        execute_on_host(host) { execute :sudo, 'systemctl', 'start', service_name }
      else
        backend.execute :sudo, 'systemctl', 'start', service_name
      end
    end

    def systemd_stop(service_name, host = nil)
      if host
        execute_on_host(host) { execute :sudo, 'systemctl', 'stop', service_name }
      else
        backend.execute :sudo, 'systemctl', 'stop', service_name
      end
    end

    def systemd_restart(service_name, host = nil)
      if host
        execute_on_host(host) { execute :sudo, 'systemctl', 'restart', service_name }
      else
        backend.execute :sudo, 'systemctl', 'restart', service_name
      end
    end

    def systemd_disable(service_name, host = nil)
      if host
        execute_on_host(host) { execute :sudo, 'systemctl', 'disable', service_name }
      else
        backend.execute :sudo, 'systemctl', 'disable', service_name
      end
    end

    def systemd_status(service_name, host = nil)
      if host
        output = nil
        execute_on_host(host) do
          output = capture :sudo, 'systemctl', 'status', service_name, raise_on_non_zero_exit: false
        end
        output
      else
        backend.capture :sudo, 'systemctl', 'status', service_name, raise_on_non_zero_exit: false
      end
    end

    def capture_on_host(host, *)
      output = nil
      execute_on_host(host) do
        output = capture(*, raise_on_non_zero_exit: false)
      end
      output
    end

    private

    def backend
      SSHKit::Backend.current || raise(Error, 'SSHKit backend not available')
    end

    def setup_sshkit
      SSHKit::Backend::Netssh.configure do |ssh|
        ssh.ssh_options = {
          user: config.user,
          keys: [File.expand_path(config.ssh_key)],
          forward_agent: config.forward_agent,
          auth_methods: config.ssh_auth_methods,
          keys_only: !config.use_ssh_agent,
          use_agent: config.use_ssh_agent,
          verify_host_key: config.verify_host_key_mode
        }
        ssh.ssh_options[:user_known_hosts_file] = [config.ssh_known_hosts_file] if config.ssh_known_hosts_file
      end
    end

    def formatted_host(host)
      case host
      when Hash
        target_host = host['host'] || host[:host]
        raise Error, 'Host entry missing host field' unless target_host

        build_sshkit_host(target_host, host['user'] || host[:user], host)
      else
        host_string = host.to_s
        return SSHKit::Host.new(host_string) if host_string.include?('@')

        build_sshkit_host(host_string, nil, nil)
      end
    end

    def build_sshkit_host(hostname, user, host_config)
      sshkit_host = SSHKit::Host.new(hostname)
      sshkit_host.user = user || config.user
      if (jump_host = config.jump_host_config(host_config))
        sshkit_host.ssh_options = { proxy: jump_proxy(jump_host) }
      end
      sshkit_host
    end

    def jump_proxy(jump_host)
      user = jump_host['user'] || config.user
      command = [
        'ssh', '-F', '/dev/null',
        '-o', 'BatchMode=yes',
        '-o', 'ForwardAgent=no',
        '-o', "StrictHostKeyChecking=#{open_ssh_host_key_mode}"
      ]
      command.push('-o', "UserKnownHostsFile=#{config.ssh_known_hosts_file}") if config.ssh_known_hosts_file
      command.push('-i', File.expand_path(config.ssh_key), '-o', 'IdentitiesOnly=yes')
      command.push('-W', '%h:%p', "#{user}@#{jump_host.fetch('host')}")
      command_line = Shellwords.join(command).gsub('\\%h', '%h').gsub('\\%p', '%p')
      Net::SSH::Proxy::Command.new(command_line)
    end

    def open_ssh_host_key_mode
      case config.verify_host_key_mode
      when :accept_new then 'accept-new'
      when :never then 'no'
      else 'yes'
      end
    end
  end
end
