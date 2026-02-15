# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.4.0] - 2026-02-15

### Changed
- Error responses now delegate to `Verikloak::ErrorResponse.build` for RFC 6750-compliant JSON output with `WWW-Authenticate` header
- Skip-path matching now uses shared `Verikloak::SkipPathMatcher` from core gem (removes duplicated logic)
- Error class hierarchy unified: `Verikloak::Audience::Error` now inherits from `Verikloak::Error`
- **BREAKING**: Minimum `verikloak` dependency raised to `>= 0.4.1, < 1.0.0`
- Dev dependency `rspec` pinned to `~> 3.13`, `rubocop-rspec` pinned to `~> 3.9`

### Fixed
- **`normalize_claims` observability**: `rescue StandardError` now captures the exception and emits a `warn` when `$DEBUG` is enabled, improving debuggability of malformed claims
- **`Audience.reset!` added**: New `reset!` class method for test teardown to prevent configuration leakage between examples

---

## [0.3.1] - 2026-01-01

### Added
- **`:any_match` profile**: New audience validation profile that passes when at least one of the required audiences is present in the token.
- **`skip_paths` configuration**: Skip audience validation for specific paths (e.g., health checks). Supports exact matches, prefix matches, wildcard patterns, and Regexp.
- **Generator improvements**: Install generator now includes `Verikloak::Audience.configure` block with all four profiles documented.

### Fixed
- **Regexp support in `skip_paths`**: Fixed `NoMethodError` when passing Regexp patterns.
- **Warning message accuracy**: Unconfigured warning now correctly states "ALL requests will be rejected with 403".
- Configuration sync now happens before middleware insertion.

### Changed
- README now correctly describes that the Railtie automatically inserts the middleware.
- Removed manual `insert_middleware` call from generated initializer (Railtie handles this automatically).

## [0.3.0] - 2026-01-01

### Fixed
- **Rails 8.x+ middleware insertion**: Fixed automatic middleware insertion not working in Rails 8.x+ due to queued middleware operations not being visible via `include?` checks.

### Changed
- Railtie initializer now specifies `before: :build_middleware_stack` to ensure middleware insertion is queued before stack construction.
- Middleware insertion now uses `app.config.middleware` instead of `app.middleware` for more reliable queuing in Rails 8.x+.
- Extracted `middleware_not_found_error?` method to handle error detection across Rails versions (Rails 7's `MiddlewareNotFound` and Rails 8+'s `RuntimeError`).

### Added
- `@middleware_insertion_attempted` class variable to prevent duplicate middleware insertion when both railtie and generator initializer run.
- `reset_middleware_insertion_flag!` method for testing purposes.
- Support for alternative error message patterns (`"does not exist"`, `/middleware.*not found/i`) for future Rails version compatibility.
- Comprehensive test coverage for:
  - `include?` early return when middleware is already present
  - Duplicate insertion prevention via flag
  - Rails 7 `MiddlewareNotFound` exception handling
  - Alternative error message patterns
  - Unexpected exception re-raising

## [0.2.9] - 2025-12-31

### Added
- **Keycloak Integration** documentation section in README:
  - Default audience behavior explanation (Access Token: `"account"`, ID Token: Client ID)
  - Step-by-step guide for configuring Audience Mapper in Keycloak
  - Configuration examples using `:allow_account` profile and array audiences
  - Troubleshooting guide with JWT decoding commands

### Documentation
- Added guidance for common Keycloak + audience validation issues
- Clarified the relationship between Keycloak client configuration and token `aud` claims

## [0.2.8] - 2025-09-28

### Changed
- Require `rails/generators` directly in the install generator and inherit via `::Rails::Generators::Base` to avoid constant lookup issues in non-Rails contexts.
- Document the generator purpose with a `desc` string so `rails g --help` includes a clearer description.

### Fixed
- Stub Thor semantics in the generator spec and restore `tmpdir` usage so error handling tests assert `Thor::Error`, matching the real generator behavior.
- Ensure the generator spec recreates missing template and destination conflict scenarios using the same API surface Rails provides.

## [0.2.7] - 2025-09-27

### Changed
- Rails Railtie now syncs `env_claims_key`, `required_aud`, and `resource_client` defaults with verikloak-rails configuration after boot.
- Generator template converted to ERB and bundled with the gem so `rails g verikloak:audience:install` produces the initializer without relying on Rails internals.
- Middleware option validation tightened to fail fast on unknown overrides with clearer error messages.

### Documentation
- Added RubyDoc comments across the Railtie to clarify initializer responsibilities and helper methods.

## [0.2.6] - 2025-09-23

### Added
- Rails generator `verikloak:audience:install` to create an initializer that inserts the audience middleware once the core Verikloak middleware is available.

### Changed
- Improved warning message when core Verikloak middleware is not present in the Rails middleware stack.
- Enhanced middleware insertion logic to provide clearer guidance on setup requirements.

## [0.2.5] - 2025-09-23

### Changed
- Use autoload for middleware to avoid circular require dependencies.
- Improve module loading performance by deferring middleware class loading until accessed.

### Added
- Comprehensive test suite for standalone middleware require scenarios.
- Test coverage for middleware functionality when loaded independently of main gem entrypoint.

## [0.2.4] - 2025-09-22

### Fixed
- Skip middleware validation even before `Rails::Generators` is loaded so `rails g verikloak:install` succeeds without a placeholder configuration.
- Treat all `verikloak:*:install` generators as safe so additional installer tasks (e.g. `verikloak:pundit:install`) can run before configuration exists.

## [0.2.3] - 2025-09-22

### Fixed
- Detect the `verikloak:install` namespace after Rails strips the `g` alias so generator invocations inside wrappers (e.g. `docker compose run`) no longer fail validation.

## [0.2.2] - 2025-09-22

### Fixed
- Skip middleware configuration validation when Rails generator commands execute so `rails g verikloak:install` can boot without preconfigured audiences.

## [0.2.1] - 2025-09-22

### Fixed
- Skip configuration validation while Rails generators run so `rails g verikloak:install` can execute before `required_aud` is configured.

## [0.2.0] - 2025-09-21

### Added
- README "Operational safeguards" section covering startup validation, logger precedence, and `:resource_or_aud` alignment guidance.
- YARD documentation for configuration helpers and middleware logging routines.

### Changed
- Tightened `resource_client` inference/validation to enforce alignment with `required_aud` and infer single-entry clients automatically.
- Prefer request-scoped loggers over `Kernel#warn` when emitting audience failure messages.
- Bumped runtime dependency to `verikloak >= 0.1.5` to pick up shared logger support.
- Improved Rails Railtie test harness to mimic real initializer registration.

## [0.1.1] - 2025-09-20

### Changed
- Documented `Configuration#safe_dup` behaviour and tightened duplication semantics.
- Expanded error class YARD docs to clarify operational response codes.

## [0.1.0] - 2025-09-20

### Added
- Rack middleware for audience validation with configurable profiles (`:strict_single`, `:allow_account`, `:resource_or_aud`).
- Configuration helpers and profile checker with suggestion logging.
- Rails railtie for automatic middleware insertion after core Verikloak.
- Error reference documentation (`ERRORS.md`) describing 403 responses and exception classes.
- English README with installation, configuration tables, and integration guidance.
