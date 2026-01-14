begin
  require 'rails/railtie'

  module BoringServices
    class Railtie < Rails::Railtie
      railtie_name :boring_services

      # Initialize service locator after Rails config is loaded
      initializer 'boring_services.initialize' do
        # Reset locator so it picks up the correct Rails environment
        BoringServices.reset_locator!
      end

      rake_tasks do
        load File.expand_path('../tasks/services.rake', __dir__)
      end

      generators do
        require_relative 'generators/boring_services/install_generator'
      end
    end
  end
rescue LoadError
  # Rails not available - gem works standalone
end
