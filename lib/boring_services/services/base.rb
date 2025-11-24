module BoringServices
  module Services
    class Base
      attr_reader :config, :ssh_executor, :service_config

      def initialize(config, ssh_executor, service_config)
        @config = config
        @ssh_executor = ssh_executor
        @service_config = service_config
      end

      def install
        raise NotImplementedError, 'Subclasses must implement #install'
      end

      def uninstall
        raise NotImplementedError, 'Subclasses must implement #uninstall'
      end

      def restart
        raise NotImplementedError, 'Subclasses must implement #restart'
      end

      protected

      def service_name
        service_config['name']
      end

      def host
        host_context_value('host')
      end

      def label
        host_context_value('label')
      end

      def port
        host_context_value('port')
      end

      def memory_mb
        host_context_value('memory_mb')
      end

      def private_ip
        host_context_value('private_ip')
      end

      def resolve_secret(key)
        Secrets.resolve(config.secrets[key])
      end

      def template_path(filename)
        File.join(BoringServices.root, 'templates', filename)
      end

      def execute_on_host(&)
        raise ArgumentError, 'block required' unless block_given?

        service_instance = self
        ssh_executor.execute_on_host_for_service(service_config) do |host_entry|
          backend = SSHKit::Backend.current || self
          service_instance.send(:with_host_context, host_entry) do
            service_instance.send(:with_backend, backend) do
              service_instance.instance_exec(&)
            end
          end
        end
      end

      def execute(*, &)
        ensure_backend!
        current_backend.execute(*, &)
      end

      def capture(*, &)
        ensure_backend!
        current_backend.capture(*, &)
      end

      def upload!(*)
        ensure_backend!
        current_backend.upload!(*)
      end

      def download!(*)
        ensure_backend!
        current_backend.download!(*)
      end

      def test(*, &)
        ensure_backend!
        current_backend.test(*, &)
      end

      def within(*, &)
        ensure_backend!
        current_backend.within(*, &)
      end

      def with(*, &)
        ensure_backend!
        current_backend.with(*, &)
      end

      def as(*, &)
        ensure_backend!
        current_backend.as(*, &)
      end

      private

      def host_context_value(key)
        context = current_host_context
        return context[key] if context.key?(key)
        return context[key.to_sym] if context.key?(key.to_sym)

        service_config[key] || service_config[key.to_sym]
      end

      def with_backend(backend)
        backend_stack.push(backend)
        yield
      ensure
        backend_stack.pop
      end

      def with_host_context(host_entry)
        previous = @current_host_context
        @current_host_context = normalize_host_entry(host_entry)
        yield
      ensure
        @current_host_context = previous
      end

      def current_host_context
        @current_host_context ||= {}
      end

      def normalize_host_entry(host_entry)
        return {} unless host_entry

        if host_entry.is_a?(Hash)
          host_entry.transform_keys(&:to_s)
        else
          { 'host' => host_entry.to_s }
        end
      end

      def current_backend
        backend_stack.last || SSHKit::Backend.current
      end

      def ensure_backend!
        raise 'SSHKit backend is not available. Use execute_on_host to run remote commands.' unless current_backend
      end

      def backend_stack
        Thread.current[:boring_services_backend_stack] ||= []
      end
    end
  end
end
