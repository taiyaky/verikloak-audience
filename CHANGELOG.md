# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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
