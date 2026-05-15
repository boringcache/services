require 'English'
require 'open3'
require 'shellwords'

module BoringServices
  class Secrets
    def self.resolve(value)
      return nil if value.nil? || value.to_s.strip.empty?

      value_str = value.to_s.strip

      if value_str.start_with?('credentials:')
        resolve_rails_credentials(value_str)
      elsif value_str.start_with?('$(') && value_str.end_with?(')')
        resolve_command(value_str[2..-2])
      elsif value_str.start_with?('$')
        resolve_env_var(value_str)
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
      runner = "puts Rails.application.credentials.dig(#{keys.map { |key| key.to_sym.inspect }.join(', ')})"
      result, stderr, status = Open3.capture3(
        { 'RAILS_ENV' => ENV.fetch('RAILS_ENV', 'production') },
        'bundle', 'exec', 'rails', 'runner', runner
      )

      unless status.success?
        detail = stderr.strip.empty? ? 'Make sure you are running from the Rails root directory.' : stderr.strip
        raise Error, "Failed to resolve Rails credentials: #{key_path}. #{detail}"
      end

      result = result.strip
      raise Error, "Rails credentials key not found: #{key_path}" if result.empty?

      result
    end

    def self.resolve_env_var(value)
      var_name = value[1..]
      ENV.fetch(var_name) do
        raise Error, "Environment variable #{var_name} not set"
      end
    end

    def self.resolve_command(command)
      argv = Shellwords.split(command)
      raise Error, 'Command secret is empty' if argv.empty?

      result, stderr, status = Open3.capture3(*argv)
      raise Error, "Command failed: #{argv.first}: #{stderr.strip}" unless status.success?

      result.strip
    end
  end
end
