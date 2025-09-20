# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2025-09-20

### Added
- Rack middleware for audience validation with configurable profiles (`:strict_single`, `:allow_account`, `:resource_or_aud`).
- Configuration helpers and profile checker with suggestion logging.
- Rails railtie for automatic middleware insertion after core Verikloak.
- Error reference documentation (`ERRORS.md`) describing 403 responses and exception classes.
- English README with installation, configuration tables, and integration guidance.
