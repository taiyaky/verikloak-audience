# Maintainers Guide

Release instructions for `verikloak-audience`. For contribution guidelines, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Prerequisites

- Push access to this repository and ownership of the gem on [RubyGems.org](https://rubygems.org/gems/verikloak-audience)
- MFA enabled on your RubyGems account (`rubygems_mfa_required` is set in the gemspec, so pushes without MFA are rejected)

## Release checklist

1. Ensure `main` is green (RSpec across all supported Rubies, RuboCop, bundler-audit).
2. Bump the version in `lib/verikloak/audience/version.rb` following [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
3. Add a dated entry to `CHANGELOG.md` describing the changes (Keep a Changelog format).
4. Update `Gemfile.lock` so the lockfile records the new version:
   ```bash
   docker compose run --rm dev bundle install
   ```
5. Run the full test suite one more time:
   ```bash
   docker compose run --rm dev rspec
   docker compose run --rm dev rubocop
   ```
6. Commit the release changes and open a pull request. Merge once CI passes.
7. Tag the merge commit on `main` and push the tag:
   ```bash
   git tag v<VERSION>
   git push origin v<VERSION>
   ```
8. Build and publish the gem:
   ```bash
   gem build verikloak-audience.gemspec
   gem push verikloak-audience-<VERSION>.gem
   ```
9. Verify the release on [RubyGems.org](https://rubygems.org/gems/verikloak-audience) and check that
   [rubydoc.info](https://rubydoc.info/gems/verikloak-audience) picks up the new version.

## Compatibility policy

- Keep the runtime dependency pinned to the current minor floor of the core gem (currently `verikloak ~> 1.1`).
- Supported Ruby versions follow the gemspec (`>= 3.1`); the CI matrix must cover every supported series.
- Coordinate breaking changes with the other gems in the Verikloak family (verikloak, verikloak-rails, verikloak-bff, verikloak-pundit) so error hierarchies and Rack env keys stay aligned.
