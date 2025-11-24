require 'rails/generators'

module BoringServices
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def create_config_file
        template 'services.yml.erb', 'config/services.yml'
      end

      def show_instructions
        puts "\n✅ BoringServices installed!"
        puts "\n📝 Next steps:"
        puts '  1. Either:'
        puts '     a) Edit config/services.yml with your service hosts, OR'
        puts '     b) Use Terraform to auto-generate config/services.yml'
        puts '  2. Deploy services: rails boring_services:setup'
        puts '  3. Check status: rails boring_services:status'
        puts "\n📚 Available: Memcached, Redis, HAProxy (SSL), Nginx"
        puts '    See config/services.example.yml in gem for examples'
      end
    end
  end
end
