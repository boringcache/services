require 'English'
module BoringServices
  class Secrets
    def self.resolve(value)
      return nil if value.nil? || value.to_s.strip.empty?

      value_str = value.to_s.strip

      if value_str.start_with?('credentials:')
        resolve_rails_credentials(value_str)
      elsif value_str.start_with?('$')
        resolve_env_var(value_str)
      elsif value_str.start_with?('$(') && value_str.end_with?(')')
        resolve_command(value_str[2..-2])
      else
        value_str
      end
    end

    def self.resolve_rails_credentials(value)
      # Extract the key path from "credentials:ssl.certificate" -> "ssl.certificate"
      key_path = value.sub(/^credentials:/, '')
      keys = key_path.split('.')

      # Use rails credentials:show to fetch the value
      # This requires being run from the Rails root directory
      command = "RAILS_ENV=production bundle exec rails runner \"puts Rails.application.credentials.dig(#{keys.map { |k| ":#{k}" }.join(', ')})\""
      result = `#{command}`.strip

      unless $CHILD_STATUS.success?
        raise Error, "Failed to resolve Rails credentials: #{key_path}. Make sure you're running from the Rails root directory."
      end

      if result.empty?
        raise Error, "Rails credentials key not found: #{key_path}"
      end

      result
    end

    def self.resolve_env_var(value)
      var_name = value[1..]
      ENV.fetch(var_name) do
        raise Error, "Environment variable #{var_name} not set"
      end
    end

    def self.resolve_command(command)
      result = `#{command}`.strip
      raise Error, "Command failed: #{command}" unless $CHILD_STATUS.success?

      result
    end
  end
end
