# Verikloak Audience Error Reference

This document captures the *current* error behaviour implemented by the `verikloak-audience` gem. Use it as a developer aid when wiring the middleware or surfacing audience failures to callers.

## Response Shape
- Status: `403 Forbidden` (or `500 Internal Server Error` for configuration failures, see below)
- Headers: `Content-Type: application/json`
- Body: `{ "error": <code>, "message": <text> }`
- Authentication headers: none added by this gem (the upstream Verikloak middleware already emits `WWW-Authenticate`).

Example 403 response:
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{"error":"insufficient_audience","message":"Audience not acceptable for profile strict_single"}
```

## Error Catalog

| Code                           | HTTP | Message template                                   | Trigger |
|--------------------------------|------|----------------------------------------------------|---------|
| `insufficient_audience`        | 403  | `Audience not acceptable for profile <profile>`    | Returned whenever the configured audience profile does not match the claims loaded from `env[config.env_claims_key]`. |
| `audience_configuration_error` | 500  | `audience configuration error` | Returned when a configuration problem (e.g. an unknown `profile`) is detected while evaluating a request. The body stays generic; the failure detail (e.g. the invalid profile value) is written to the request logger only. Boot-time validation (`Configuration#validate!`) normally catches this before any request is served; this response guards deployments where validation was skipped (e.g. an unconfigured Rails boot). |

### Trigger details
- Claims are read from `env[config.env_claims_key]` (default: `"verikloak.user"`). Missing claims are treated as `{}`.
- Validation is delegated to `Verikloak::Audience::Checker.ok?`, which supports profiles `:strict_single`, `:allow_account`, `:any_match`, and `:resource_or_aud`.
- When validation fails and `config.suggest_in_logs` is true (default), the middleware emits a `warn` message to STDERR such as:
  ```
  [verikloak-audience] insufficient_audience; suggestion profile=:allow_account aud=["my-api","account"]
  ```
  When no profile would accept the observed claims, the log reads `no profile matches the observed aud` instead of naming a profile. This logging side-effect has no impact on the HTTP response.

## Exception Classes

| Class                                | Default code               | Default status | Notes |
|--------------------------------------|----------------------------|----------------|-------|
| `Verikloak::Audience::Error`         | `audience_error`           | 403            | Base class exposing `#code` and `#http_status`; not raised automatically by the middleware but available for host apps. |
| `Verikloak::Audience::Forbidden`     | `insufficient_audience`    | 403            | Thin wrapper around `Error`. Useful if your application raises exceptions instead of returning JSON responses directly. |
| `Verikloak::Audience::ConfigurationError` | `audience_configuration_error` | 500     | Raised by `Configuration#validate!` and configuration writers when settings are missing or inconsistent; rendered as the 500 JSON response if it surfaces during a request. |

These classes exist for integration purposes (e.g., controller helpers) and mirror the JSON shape returned by the Rack middleware. If you rescue them inside a Rails app, you can map them to the same 403 payload shown above.

## Operational Notes
- Audience mismatches always resolve to the single 403 response. The only other status this gem emits is the 500 `audience_configuration_error` response described above, which signals a misconfiguration rather than a client failure.
- Upstream Verikloak middleware remains responsible for token verification errors (401/503/etc.). Place `Verikloak::Audience::Middleware` after it so that verified claims are available for audience checks.
- Adjust `config.required_aud`, `config.profile`, and `config.resource_client` to control what qualifies as a passing audience.
