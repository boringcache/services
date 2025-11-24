namespace :boring_services do
  def boringservices_cli(*args)
    cli_args = ['bundle', 'exec', 'boringservices', *args]
    env = ENV.fetch('BORING_SERVICES_ENV', nil)
    cli_args += ['-e', env] if env && !env.empty?
    config_path = ENV.fetch('BORING_SERVICES_CONFIG', nil)
    cli_args += ['-c', config_path] if config_path && !config_path.empty?
    system(*cli_args)
  end

  desc 'Install BoringServices configuration'
  task :install do
    system('rails generate boring_services:install')
  end

  desc 'Deploy all services'
  task :setup do
    config_path = 'config/services.yml'
    unless File.exist?(config_path)
      puts "⚠️  Config file not found: #{config_path}"
      puts '📦 Running install generator first...'
      system('rails generate boring_services:install') || raise('Failed to generate config file')
    end
    boringservices_cli('setup')
  end

  desc 'Check services health'
  task :health do
    boringservices_cli('status')
  end

  desc 'Restart all services'
  task :restart do
    boringservices_cli('restart')
  end

  desc 'Show services status'
  task :status do
    puts "\n🔧 Infrastructure Services Status\n\n"
    boringservices_cli('status')
  end
end
