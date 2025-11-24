# Contributing to BoringServices

Thank you for your interest in contributing to BoringServices! We welcome contributions from the community.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/YOUR_USERNAME/boring_services.git`
3. Create a feature branch: `git checkout -b my-new-feature`
4. Make your changes
5. Run tests: `bundle exec rake test`
6. Commit your changes: `git commit -am 'Add new feature'`
7. Push to the branch: `git push origin my-new-feature`
8. Create a Pull Request

## Development Setup

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rake test

# Run rubocop
bundle exec rubocop

# Test CLI locally
bundle exec exe/boringservices version
```

## Testing with Services

BoringServices manages infrastructure services. For local testing:

```bash
# Test with local services
bundle exec rake test

# Test specific service modules
bundle exec rake test TEST=test/services/redis_test.rb
```

## Code Style

- Follow the Ruby Style Guide
- Run `rubocop` before committing
- Write tests for new features
- Keep commits atomic and well-described

## Adding New Services

When adding a new service:

1. Create a new service class in `lib/boring_services/services/`
2. Inherit from `BoringServices::Services::Base`
3. Implement `install`, `configure`, and `health_check` methods
4. Add tests in `test/services/`
5. Update README.md with service documentation

## Testing

- All new features should include tests
- Test service installation and configuration
- Run the full test suite before submitting PR
- Ensure all tests pass

## Pull Request Guidelines

- Keep PRs focused on a single feature or fix
- Include tests for new functionality
- Update CHANGELOG.md with your changes
- Update documentation as needed
- Ensure CI passes

## Reporting Issues

- Use GitHub Issues to report bugs
- Include service versions (Redis, Memcached, etc.)
- Include steps to reproduce
- Include your Ruby version and OS
- Include relevant error messages and logs

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
