require 'test_helper'
require 'tempfile'

class ConfigurationTest < Minitest::Test
  def test_initialization_loads_config
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal 'test', config.environment
    refute_nil config.config
  end

  def test_service_config_finds_service
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    service = config.service_config('redis')

    assert_equal 'redis', service['name']
    assert_equal true, service['enabled']
    assert_equal 6379, service['port']
  end

  def test_service_config_returns_nil_for_missing_service
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_nil config.service_config('nonexistent')
  end

  def test_service_enabled_returns_true_when_enabled
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert config.service_enabled?('redis')
  end

  def test_service_enabled_returns_false_when_disabled
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    refute config.service_enabled?('memcached')
  end

  def test_service_enabled_returns_false_for_missing_service
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    refute config.service_enabled?('nonexistent')
  end

  def test_services_returns_all_services
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    services = config.services

    assert_equal 2, services.length
    assert_equal 'redis', services[0]['name']
    assert_equal 'memcached', services[1]['name']
  end

  def test_enabled_services_returns_only_enabled
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    enabled = config.enabled_services

    assert_equal 1, enabled.length
    assert_equal 'redis', enabled[0]['name']
  end

  def test_user_returns_configured_user
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal 'testuser', config.user
  end

  def test_user_defaults_to_ubuntu
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'production')
    assert_equal 'ubuntu', config.user
  end

  def test_ssh_key_returns_configured_key
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal '~/.ssh/test_key', config.ssh_key
  end

  def test_ssh_key_defaults
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'production')
    assert_equal '~/.ssh/id_rsa', config.ssh_key
  end

  def test_forward_agent
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal false, config.forward_agent
  end

  def test_forward_agent_defaults_to_true
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'production')
    assert_equal true, config.forward_agent
  end

  def test_use_ssh_agent
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal true, config.use_ssh_agent
  end

  def test_use_ssh_agent_defaults_to_false
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'production')
    assert_equal false, config.use_ssh_agent
  end

  def test_ssh_auth_methods
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal %w[publickey password], config.ssh_auth_methods
  end

  def test_ssh_auth_methods_defaults_to_publickey
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'production')
    assert_equal ['publickey'], config.ssh_auth_methods
  end

  def test_secrets_returns_empty_hash_by_default
    config = BoringServices::Configuration.new(fixture_path('test_config.yml'), 'test')
    assert_equal({}, config.secrets)
  end

  def test_raises_error_for_missing_config_file
    error = assert_raises(BoringServices::Error) do
      BoringServices::Configuration.new('/nonexistent/config.yml', 'test')
    end
    assert_match(/Config file not found/, error.message)
  end

  def test_raises_error_for_missing_environment
    error = assert_raises(BoringServices::Error) do
      BoringServices::Configuration.new(fixture_path('test_config.yml'), 'nonexistent')
    end
    assert_match(/Environment 'nonexistent' not found/, error.message)
  end

  private

  def fixture_path(filename)
    File.join(__dir__, 'fixtures', filename)
  end
end
