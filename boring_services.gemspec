require_relative 'lib/boring_services/version'

Gem::Specification.new do |spec|
  spec.name = 'boring_services'
  spec.version = BoringServices::VERSION
  spec.authors = ['BoringCache']
  spec.email = ['oss@boringcache.com']

  spec.summary = 'Deploy infrastructure services for Ruby & Rails apps'
  spec.description = 'Simple deployment and management of infrastructure services ' \
                     'like Memcached, Redis, HAProxy, and Nginx. Works standalone or with Rails.'
  spec.homepage = 'https://github.com/boringcache/boring_services'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.4.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/boringcache/boring_services'
  spec.metadata['documentation_uri'] = 'https://github.com/boringcache/boring_services/blob/main/README.md'
  spec.metadata['changelog_uri'] = 'https://github.com/boringcache/boring_services/blob/main/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          lib/tasks/**/*.rake
                          templates/**/*
                          exe/*
                          LICENSE
                          README.md
                        ])
  spec.bindir = 'exe'
  spec.executables = ['boringservices']
  spec.require_paths = ['lib']

  spec.add_dependency 'bcrypt_pbkdf', '~> 1.1'
  spec.add_dependency 'ed25519', '~> 1.3'
  spec.add_dependency 'sshkit', '~> 1.21'
  spec.add_dependency 'thor', '~> 1.3'

  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rubocop', '~> 1.50'
  spec.add_development_dependency 'simplecov', '~> 0.22'
end
