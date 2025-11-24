module BoringServices
  class HealthChecker
    attr_reader :config, :ssh_executor

    def initialize(config)
      @config = config
      @ssh_executor = SSHExecutor.new(config)
    end

    def check_all
      results = {}
      config.enabled_services.each do |service|
        results[service['name']] = check_service(service)
      end
      results
    end

    def check_service(service)
      service_name = service['name']
      host = service['host']
      return { status: 'no_host' } unless host

      host_result = check_service_on_host(service_name, host)

      {
        status: host_result[:running] ? 'healthy' : 'unhealthy',
        host: host_result
      }
    end

    private

    def check_service_on_host(service_name, host)
      result = { running: false, message: '' }

      ssh_executor.execute_on_host(host) do
        status_output = ssh_executor.systemd_status(service_name)
        result[:running] = status_output.include?('active (running)')
        result[:message] = status_output
      end

      result
    rescue StandardError => e
      { running: false, message: e.message }
    end
  end
end
