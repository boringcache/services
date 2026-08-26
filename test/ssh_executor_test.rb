require 'test_helper'
require 'tempfile'

class SSHExecutorTest < Minitest::Test
  def test_target_uses_the_configured_jump_host_and_known_hosts_file
    Tempfile.create('known-hosts') do |known_hosts|
      config_file = Tempfile.new(['services', '.yml'])
      config_file.write <<~YAML
        test:
          user: ubuntu
          ssh_key: /tmp/deploy-key
          ssh_known_hosts_file: #{known_hosts.path}
          verify_host_key: always
          services:
            - name: redis
              hosts:
                - host: 1.2.3.4
                  label: jump
                - host: 5.6.7.8
                  label: target
                  jump_host: jump
      YAML
      config_file.flush
      config = BoringServices::Configuration.new(config_file.path, 'test')
      executor = BoringServices::SSHExecutor.new(config)

      host = executor.send(:formatted_host, config.host_config('target'))
      proxy = host.ssh_options.fetch(:proxy)

      assert_instance_of Net::SSH::Proxy::Command, proxy
      assert_includes proxy.command_line_template, 'ssh -F /dev/null'
      assert_includes proxy.command_line_template, 'StrictHostKeyChecking\\=yes'
      assert_includes proxy.command_line_template, "UserKnownHostsFile\\=#{known_hosts.path}"
      assert_includes proxy.command_line_template, '-W %h:%p ubuntu@1.2.3.4'
    ensure
      config_file.close!
    end
  end
end
