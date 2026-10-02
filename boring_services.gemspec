require_relative 'lib/boring_services/version'

Gem::Specification.new do |spec|
  spec.name = 'boring_services'
  spec.version = BoringServices::VERSION
  spec.authors = ['BoringCache']
  spec.email = ['oss@boringcache.com']

  spec.summary = 'Deploy infrastructure services for Ruby & Rails apps'
  spec.description = 'Simple deployment and management of infrastructure services ' \
                     'like Memcached, Redis, HAProxy, and Nginx. Works standalone or with Rails.'
  spec.homepage = 'https://github.com/boringcache/services'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.0'

  spec.metadata['source_code_uri'] = "https://github.com/boringcache/services/tree/v#{spec.version}"
  spec.metadata['documentation_uri'] = 'https://github.com/boringcache/services/blob/main/README.md'
  spec.metadata['changelog_uri'] = 'https://github.com/boringcache/services/blob/main/CHANGELOG.md'
  spec.metadata['bug_tracker_uri'] = 'https://github.com/boringcache/services/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          lib/tasks/**/*.rake
                          templates/**/*
                          exe/*
                          CHANGELOG.md
                          LICENSE
                          README.md
                          SECURITY.md
                        ])
  spec.bindir = 'exe'
  spec.executables = ['boringservices']
  spec.require_paths = ['lib']

  spec.add_dependency 'bcrypt_pbkdf', '~> 1.1'
  spec.add_dependency 'ed25519', '~> 1.4'
  spec.add_dependency 'sshkit', '~> 1.25'
  spec.add_dependency 'thor', '~> 1.5'
end
