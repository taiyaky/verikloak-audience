# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

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
