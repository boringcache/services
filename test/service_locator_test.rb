require 'test_helper'

class ServiceLocatorTest < Minitest::Test
  def setup
    @config = BoringServices::Configuration.new(fixture_path('multi_region_config.yml'), 'test')
    @locator = BoringServices::ServiceLocator.new(@config)
  end

  # hosts_for tests

  def test_hosts_for_returns_all_redis_hosts
    hosts = @locator.hosts_for('redis')

    assert_equal 4, hosts.length
    assert_equal '10.8.0.10', hosts[0][:private_ip]
    assert_equal 'redis-eu-gcp', hosts[0][:label]
  end

  def test_hosts_for_returns_hosts_from_array_format
    hosts = @locator.hosts_for('memcached')

    assert_equal 2, hosts.length
    assert_equal '10.8.0.20', hosts[0][:private_ip]
    assert_equal 'memcached-us-east', hosts[0][:label]
  end

  def test_hosts_for_returns_simple_hosts
    hosts = @locator.hosts_for('haproxy')

    assert_equal 2, hosts.length
    assert_equal '10.0.0.100', hosts[0][:host]
    assert_nil hosts[0][:private_ip]
    assert_nil hosts[0][:label]
  end

  def test_hosts_for_returns_empty_for_unknown_service
    hosts = @locator.hosts_for('unknown')
    assert_empty hosts
  end

  # host_by_label tests

  def test_host_by_label_returns_private_ip
    host = @locator.host_by_label('redis', 'redis-eu-gcp')
    assert_equal '10.8.0.10', host
  end

  def test_host_by_label_returns_nil_for_unknown_label
    host = @locator.host_by_label('redis', 'nonexistent')
    assert_nil host
  end

  def test_host_by_label_works_with_memcached
    host = @locator.host_by_label('memcached', 'memcached-us-west')
    assert_equal '10.8.0.21', host
  end

  # hosts_by_label tests

  def test_hosts_by_label_returns_hash
    hosts = @locator.hosts_by_label('redis')

    assert_instance_of Hash, hosts
    assert_equal 4, hosts.size
    assert_equal '10.8.0.10', hosts['redis-eu-gcp']
    assert_equal '10.8.0.61', hosts['redis-us-gcp']
  end

  def test_hosts_by_label_excludes_unlabeled_hosts
    hosts = @locator.hosts_by_label('haproxy')
    assert_empty hosts
  end

  # all_ips tests

  def test_all_ips_returns_private_ips_when_available
    ips = @locator.all_ips('redis')

    assert_equal 4, ips.length
    assert_includes ips, '10.8.0.10'
    assert_includes ips, '10.8.0.61'
  end

  def test_all_ips_returns_hosts_when_no_private_ip
    ips = @locator.all_ips('haproxy')

    assert_equal 2, ips.length
    assert_includes ips, '10.0.0.100'
    assert_includes ips, '10.0.0.101'
  end

  # port_for tests

  def test_port_for_returns_port
    assert_equal 6379, @locator.port_for('redis')
    assert_equal 11211, @locator.port_for('memcached')
    assert_equal 80, @locator.port_for('haproxy')
  end

  def test_port_for_returns_nil_for_unknown_service
    assert_nil @locator.port_for('unknown')
  end

  # redis_url tests

  def test_redis_url_with_label
    url = @locator.redis_url(label: 'redis-us-gcp', password: 'secret', db: 1)
    assert_equal 'redis://:secret@10.8.0.61:6379/1', url
  end

  def test_redis_url_without_password
    url = @locator.redis_url(label: 'redis-eu-gcp', db: 0)
    assert_equal 'redis://10.8.0.10:6379/0', url
  end

  def test_redis_url_returns_nil_for_unknown_label
    url = @locator.redis_url(label: 'nonexistent')
    assert_nil url
  end

  # memcached_servers tests

  def test_memcached_servers_with_label
    servers = @locator.memcached_servers(label: 'memcached-us-east')
    assert_equal '10.8.0.20:11211', servers
  end

  def test_memcached_servers_without_label_returns_all
    servers = @locator.memcached_servers
    assert_equal '10.8.0.20:11211,10.8.0.21:11211', servers
  end

  private

  def fixture_path(filename)
    File.join(__dir__, 'fixtures', filename)
  end
end
